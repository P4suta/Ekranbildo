import EkranbildoContracts
@testable import EkranbildoCore
import EkranbildoTestKit
import Testing

@Suite("Synthesis")
struct SynthesisTests {
    private let synthesis = Synthesis()

    private func scene(
        labels: [String],
        background: ImageRef? = nil
    ) -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            background: background,
            annotations: labels.enumerated().map { index, label in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: SceneRect(
                        x: Double(index) * 30, y: 40, width: 60, height: 24),
                    label: label,
                    placement: Placement(direction: .e, leaderLength: 70),
                    badge: BadgeNumber(index + 1)
                )
            },
            style: .standard
        )
    }

    @Test(
        "Nothing that was written on the screen survives",
        arguments: [
            "Account 4111 1111 1111 1111",
            "yasunobu@example.com",
            "Delete the production database",
            "保存する",
            "sk-proj-abcdefghijklmnopqrstuvwxyz",
        ]
    )
    func secretsDoNotSurvive(secret: String) {
        let safe = synthesis.synthesised(scene(labels: [secret]))
        for label in safe.annotations.map(\.label) {
            #expect(!label.contains(secret))
            for word in secret.split(separator: " ") where word.count > 2 {
                #expect(!label.contains(word))
            }
        }
    }

    @Test("No character is left where it was")
    func noCharacterSurvivesInPlace() {
        let original = "Save the document"
        let safe = synthesis.synthesised(scene(labels: [original]))
        let replaced = safe.annotations[0].label

        for (was, now) in zip(original, replaced) where was != " " {
            #expect(was != now, "'\(was)' was left where it was")
        }
    }

    @Test("A picture is replaced by one that is not it")
    func picturesAreReplaced() throws {
        let original = ImageRef(contentHash: "the-screenshot", pixelWidth: 800, pixelHeight: 600)
        let safe = synthesis.synthesised(scene(labels: ["Save"], background: original))

        let replaced = try #require(safe.background)
        #expect(replaced.contentHash != original.contentHash)
        #expect(!replaced.contentHash.contains("the-screenshot"))
    }

    @Test("Every box stays exactly where it was")
    func geometrySurvives() {
        let original = scene(labels: ["Save", "Cancel", "Open the settings"])
        let safe = synthesis.synthesised(original)

        #expect(safe.canvas == original.canvas)
        #expect(safe.style == original.style)
        #expect(safe.annotations.map(\.target) == original.annotations.map(\.target))
        #expect(safe.annotations.map(\.placement) == original.annotations.map(\.placement))
        #expect(safe.annotations.map(\.id) == original.annotations.map(\.id))
    }

    @Test("Step numbers stay as they were")
    func badgesSurvive() {
        let original = scene(labels: ["First", "Second", "Third"])
        let safe = synthesis.synthesised(original)
        #expect(safe.annotations.map(\.badge) == original.annotations.map(\.badge))
    }

    @Test(
        "A label keeps its length",
        arguments: ["", "OK", "Save", "Open the settings panel", "保存する"]
    )
    func lengthSurvives(label: String) {
        let safe = synthesis.synthesised(scene(labels: [label]))
        #expect(safe.annotations[0].label.count == label.count)
    }

    @Test("Words stay the lengths they were")
    func wordShapeSurvives() {
        let safe = synthesis.synthesised(scene(labels: ["Open the settings panel"]))
        let words = safe.annotations[0].label.split(separator: " ", omittingEmptySubsequences: false)
        #expect(words.map(\.count) == [4, 3, 8, 5])
    }

    @Test(
        "A stand-in is the same kind of writing as what it replaced",
        arguments: ["保存する", "カタカナ", "\u{D55C}\u{AD6D}\u{C5B4}"]
    )
    func widthClassSurvives(text: String) {
        let safe = synthesis.synthesised(scene(labels: [text]))
        for character in safe.annotations[0].label {
            let scalar = character.unicodeScalars.first?.value ?? 0
            #expect(scalar > FullWidth.lowest, "'\(character)' is not the width it replaced")
        }
    }

    private enum FullWidth {
        static let lowest: UInt32 = 0x2FFF
    }

    @Test("English stays English-shaped")
    func latinStaysLatin() {
        let safe = synthesis.synthesised(scene(labels: ["Save"]))
        for character in safe.annotations[0].label {
            #expect(character.isASCII, "'\(character)' is not the width it replaced")
        }
    }

    @Test("A mixed label keeps its mixture")
    func mixedStaysMixed() {
        let safe = synthesis.synthesised(scene(labels: ["Save 保存"]))
        let replaced = Array(safe.annotations[0].label)
        let english = replaced.prefix(4).allSatisfy(\.isASCII)
        let japanese = replaced.suffix(2).allSatisfy { !$0.isASCII }
        #expect(english)
        #expect(japanese)
    }

    @Test("A picture keeps its size")
    func pictureSizeSurvives() throws {
        let original = ImageRef(contentHash: "shot", pixelWidth: 800, pixelHeight: 600)
        let safe = try #require(
            synthesis.synthesised(scene(labels: ["Save"], background: original)).background)
        #expect(safe.pixelWidth == 800)
        #expect(safe.pixelHeight == 600)
    }

    @Test("The same words become the same stand-in")
    func sameWordsSameStandIn() {
        let safe = synthesis.synthesised(scene(labels: ["Save", "Save"]))
        #expect(safe.annotations[0].label == safe.annotations[1].label)
    }

    @Test("Different words become different stand-ins")
    func differentWordsDifferentStandIns() {
        let safe = synthesis.synthesised(scene(labels: ["Save", "Open", "Quit"]))
        #expect(Set(safe.annotations.map(\.label)).count == 3)
    }

    @Test("Synthesising is reproducible")
    func reproducible() {
        let original = scene(
            labels: ["Save", "Open the settings", "保存する"],
            background: ImageRef(contentHash: "shot", pixelWidth: 80, pixelHeight: 60)
        )
        #expect(isReproducible { self.synthesis.synthesised(original) })
    }

    @Test("Synthesising what is already synthesised is still safe and still fits")
    func twiceIsStillSafe() {
        let original = "Open the settings"
        let once = synthesis.synthesised(scene(labels: [original]))
        let twice = synthesis.synthesised(once)

        #expect(!twice.annotations[0].label.contains(original))
        #expect(twice.annotations[0].label.count == original.count)
        #expect(twice.annotations[0].target == once.annotations[0].target)
    }

    @Test("A scene of nothing synthesises to a scene of nothing")
    func emptyScene() {
        let empty = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            background: nil,
            annotations: [],
            style: .standard
        )
        #expect(synthesis.synthesised(empty) == empty)
    }

    @Test("Where the pointer was stays where it was")
    func cursorSurvives() throws {
        let cursor = Cursor(position: ScenePoint(x: 42, y: 17), opacity: 0.5, ripple: 0.25)
        let original = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 100),
            background: nil,
            annotations: [],
            style: .standard,
            cursor: cursor
        )
        #expect(try #require(synthesis.synthesised(original).cursor) == cursor)
    }
}
