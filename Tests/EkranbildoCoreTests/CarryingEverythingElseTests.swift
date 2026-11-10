import EkranbildoContracts
@testable import EkranbildoCore
import EkranbildoGeometry
import Testing

@Suite("Changing one thing keeps the rest")
struct CarryingEverythingElseTests {

    private static let annotation = Annotation(
        id: AnnotationID(7),
        target: SceneRect(x: 12, y: 34, width: 56, height: 78),
        label: "What it says",
        placement: Placement(direction: .ne, leaderLength: 64),
        badge: BadgeNumber(3),
        isPinned: true
    )

    @Test("A new placement changes the placement and nothing else")
    func newPlacement() {
        let chosen = Placement(direction: .sw, leaderLength: 96)
        let after = Self.annotation.replacing(placement: chosen)
        #expect(after.placement == chosen)
        #expect(after.id == Self.annotation.id)
        #expect(after.target == Self.annotation.target)
        #expect(after.label == Self.annotation.label)
        #expect(after.badge == Self.annotation.badge)
        #expect(after.isPinned == Self.annotation.isPinned)
    }

    @Test("Pinning a placement changes the placement and the pin, and nothing else")
    func pinned() {
        let chosen = Placement(direction: .sw, leaderLength: 96)
        let after = Self.annotation.replacing(placement: chosen, pinned: true)
        #expect(after.placement == chosen)
        #expect(after.isPinned)
        #expect(after.badge == Self.annotation.badge)
        #expect(after.label == Self.annotation.label)
        #expect(after.target == Self.annotation.target)
    }

    @Test("A new label changes the label and nothing else")
    func newLabel() {
        let after = Self.annotation.replacing(label: "Something else")
        #expect(after.label == "Something else")
        #expect(after.placement == Self.annotation.placement)
        #expect(after.badge == Self.annotation.badge)
        #expect(after.isPinned == Self.annotation.isPinned)
        #expect(after.target == Self.annotation.target)
    }

    @Test("A new target changes the target and nothing else")
    func newTarget() {
        let moved = SceneRect(x: 100, y: 200, width: 56, height: 78)
        let after = Self.annotation.replacing(target: moved)
        #expect(after.target == moved)
        #expect(after.placement == Self.annotation.placement)
        #expect(after.label == Self.annotation.label)
        #expect(after.badge == Self.annotation.badge)
        #expect(after.isPinned == Self.annotation.isPinned)
    }

    @Test("Changing nothing changes nothing")
    func changingNothing() {
        #expect(Self.annotation.replacing(label: Self.annotation.label) == Self.annotation)
        #expect(
            Self.annotation.replacing(target: Self.annotation.target) == Self.annotation)
        #expect(
            Self.annotation.replacing(
                placement: Self.annotation.placement,
                pinned: Self.annotation.isPinned
            ) == Self.annotation)
    }
}

@Suite("Changing one thing about a scene keeps the rest")
struct SceneCarriesEverythingElseTests {

    private static let scene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
        background: ImageRef(contentHash: "picture", pixelWidth: 800, pixelHeight: 600),
        annotations: [
            Annotation(
                id: AnnotationID(1),
                target: SceneRect(x: 10, y: 10, width: 20, height: 20),
                label: "One",
                placement: Placement(direction: .n, leaderLength: 40)
            )
        ],
        style: .standard,
        cursor: Cursor(position: ScenePoint(x: 33, y: 44), opacity: 0.5, ripple: 0.25),
        unknownKeys: UnknownKeys(
            entries: [UnknownEntry(key: "somethingNewerWrote", value: .string("kept"))])
    )

    @Test("New annotations change the annotations and nothing else")
    func newAnnotations() {
        let after = Self.scene.replacing(annotations: [])
        #expect(after.annotations.isEmpty)
        #expect(after.canvas == Self.scene.canvas)
        #expect(after.background == Self.scene.background)
        #expect(after.cursor == Self.scene.cursor)
        #expect(after.unknownKeys == Self.scene.unknownKeys)
    }

    @Test("Taking the background away leaves the pointer and the unknown keys")
    func withoutBackground() {
        let after = Self.scene.replacing(background: .some(nil))
        #expect(after.background == nil)
        #expect(after.cursor == Self.scene.cursor)
        #expect(after.unknownKeys == Self.scene.unknownKeys)
        #expect(after.annotations == Self.scene.annotations)
    }

    @Test("Changing nothing changes nothing")
    func changingNothing() {
        #expect(Self.scene.replacing() == Self.scene)
        #expect(Self.scene.replacing(annotations: Self.scene.annotations) == Self.scene)
    }

    @Test("What a newer build wrote survives being solved and drawn")
    func unknownKeysSurvive() {
        var carried = Self.scene
        for _ in 0..<4 {
            carried = carried.replacing(annotations: carried.annotations)
        }
        #expect(carried.unknownKeys == Self.scene.unknownKeys)
    }
}

@Suite("Synthesising a scene")
struct SynthesisKeepsShapeTests {

    private static let scene = Scene(
        canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
        background: nil,
        annotations: [
            Annotation(
                id: AnnotationID(1),
                target: SceneRect(x: 10, y: 10, width: 20, height: 20),
                label: "Something private",
                placement: Placement(direction: .n, leaderLength: 40),
                badge: BadgeNumber(2),
                isPinned: true
            )
        ],
        style: .standard,
        cursor: Cursor(position: ScenePoint(x: 5, y: 6)),
        unknownKeys: UnknownKeys(
            entries: [UnknownEntry(key: "aKeyFromANewerBuild", value: .string("possibly private"))])
    )

    private static var synthesised: Scene { Synthesis().synthesised(scene) }

    @Test("What a newer build wrote is dropped, because nobody here knows what is in it")
    func unknownKeysGo() {
        #expect(Self.synthesised.unknownKeys == .nothing)
    }

    @Test("The words change")
    func wordsChange() {
        #expect(Self.synthesised.annotations[0].label != Self.scene.annotations[0].label)
    }

    @Test("Everything that decides the layout stays, or the report shows a different picture")
    func shapeStays() {
        let after = Self.synthesised
        #expect(after.canvas == Self.scene.canvas)
        #expect(after.style == Self.scene.style)
        #expect(after.cursor == Self.scene.cursor)
        #expect(after.annotations[0].target == Self.scene.annotations[0].target)
        #expect(after.annotations[0].placement == Self.scene.annotations[0].placement)
        #expect(after.annotations[0].badge == Self.scene.annotations[0].badge)
        #expect(after.annotations[0].isPinned == Self.scene.annotations[0].isPinned)
        #expect(after.annotations[0].id == Self.scene.annotations[0].id)
    }

    @Test("Synthesising twice gives the same thing")
    func stable() {
        #expect(Synthesis().synthesised(Self.scene) == Self.synthesised)
    }
}
