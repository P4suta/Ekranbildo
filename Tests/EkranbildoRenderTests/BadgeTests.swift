import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("Numbered badges")
struct BadgeTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    private let measurer = TabulatedTextMeasurer.uniform()

    private func annotation(_ number: Int, at x: Double) -> Annotation {
        Annotation(
            id: AnnotationID(UInt32(number)),
            target: SceneRect(x: x, y: 140, width: 30, height: 20),
            label: "Step \(number)",
            placement: Placement(direction: .n, leaderLength: 40),
            badge: BadgeNumber(number)
        )
    }

    private func scene(_ numbers: [Int]) -> Scene {
        Scene(
            canvas: Self.canvas,
            background: nil,
            annotations: numbers.enumerated().map { index, number in
                annotation(number, at: 40 + Double(index) * 90)
            },
            style: .standard
        )
    }

    private func build(_ scene: Scene) -> DrawList {
        DrawListBuilder(measurer: measurer).build(scene)
    }

    private func text(of scene: Scene) -> String {
        build(scene).canonicalText
    }

    @Test("A badge is drawn for an annotation that has one")
    func drawsBadge() {
        #expect(text(of: scene([1])).contains("\"1\""))
    }

    @Test("Nothing extra is drawn for an annotation without one")
    func noBadge() {
        let plain = Scene(
            canvas: Self.canvas,
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 40, y: 140, width: 30, height: 20),
                    label: "Plain",
                    placement: Placement(direction: .n, leaderLength: 40)
                )
            ],
            style: .standard
        )
        let withBadge = build(scene([1]))
        #expect(build(plain).commands.count < withBadge.commands.count)
    }

    @Test("A badge is drawn as a disc, not a rectangle")
    func badgeIsRound() {
        #expect(text(of: scene([1])).contains("C "))
    }

    @Test("Every number that went in comes out")
    func keepsNumbers() {
        let drawn = text(of: scene([3, 1, 7]))
        for number in [3, 1, 7] {
            #expect(drawn.contains("\"\(number)\""), "\(number) is not in the picture")
        }
    }

    @Test("A repeated number is drawn twice")
    func repeatedNumber() {
        let drawn = text(of: scene([2, 2]))
        #expect(drawn.components(separatedBy: "\"2\"").count - 1 == 2)
    }

    @Test("A number nobody would write is still drawn")
    func unusualNumbers() {
        let drawn = text(of: scene([0, 42]))
        #expect(drawn.contains("\"0\""))
        #expect(drawn.contains("\"42\""))
    }

    @Test("A badge sits inside the plate, not on what the arrow points at")
    func badgeInThePlate() throws {
        let subject = annotation(1, at: 100)
        let resolved = ResolvedPlacement(
            target: subject.target,
            placement: try #require(subject.placement),
            style: .standard
        )
        let plate = resolved.labelBox(
            textSize: LabelMetrics.size(of: subject, style: .standard, measurer: measurer),
            style: .standard
        )
        let disc = BadgeGeometry.rect(in: plate, style: .standard)

        #expect(plate.raw.contains(disc.raw), "the disc is outside the plate")
        #expect(!disc.raw.contains(resolved.tip.raw), "the disc covers what the arrow points at")
        #expect(!Geo.overlaps(disc.raw, subject.target.raw), "the disc covers the target")
    }

    @Test("A numbered plate is wider than the same words without a number")
    func numberedPlateIsWider() {
        let numbered = annotation(1, at: 100)
        let plain = Annotation(
            id: numbered.id,
            target: numbered.target,
            label: numbered.label,
            placement: numbered.placement
        )
        let withNumber = LabelMetrics.size(of: numbered, style: .standard, measurer: measurer)
        let without = LabelMetrics.size(of: plain, style: .standard, measurer: measurer)
        #expect(withNumber.width > without.width)
        #expect(withNumber.width - without.width == LabelMetrics.badgeAllowance(style: .standard))
    }

    @Test("Every badge is the same size, however many digits it has")
    func sameSize() {
        let narrow = BadgeGeometry.rect(
            in: SceneRect(x: 0, y: 0, width: 60, height: 30), style: .standard)
        let wide = BadgeGeometry.rect(
            in: SceneRect(x: 200, y: 100, width: 300, height: 30), style: .standard)
        #expect(narrow.raw.width == wide.raw.width)
        #expect(narrow.raw.height == wide.raw.height)
        #expect(narrow.raw.width == narrow.raw.height, "a badge should be round")
    }

    @Test("The words start after the disc, not under it")
    func wordsClearTheDisc() throws {
        let subject = annotation(1, at: 100)
        let list = build(
            Scene(
                canvas: Self.canvas,
                background: nil,
                annotations: [subject],
                style: .standard
            )
        )

        let run = try #require(Self.labelRun(in: list, saying: subject.label))
        let resolved = ResolvedPlacement(
            target: subject.target,
            placement: try #require(subject.placement),
            style: .standard
        )
        let plate = resolved.labelBox(
            textSize: LabelMetrics.size(of: subject, style: .standard, measurer: measurer),
            style: .standard
        )
        let disc = BadgeGeometry.rect(in: plate, style: .standard)

        #expect(run.baselineOrigin.x >= disc.maxX, "the words are drawn under the disc")
        #expect(
            run.baselineOrigin.x - disc.maxX >= StyleTokens.standard.badgeGap
                - Tolerances.placement,
            "the words touch the disc"
        )
    }

    private static func labelRun(in list: DrawList, saying label: String) -> TextRun? {
        for command in list.commands {
            guard case .text(let run) = command, run.text == label else { continue }
            return run
        }
        return nil
    }

    private enum Tolerances {
        static let placement: Double = 1
    }

    @Test("Drawing badges is reproducible")
    func reproducible() {
        let subject = scene([1, 2, 3])
        #expect(isReproducible { build(subject) })
    }
}

@Suite("Badges read the other way")
struct MirroredBadgeTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    private let measurer = TabulatedTextMeasurer.uniform()

    private func annotation() -> Annotation {
        Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 180, y: 140, width: 40, height: 20),
            label: "Step one",
            placement: Placement(direction: .n, leaderLength: 50),
            badge: BadgeNumber(1)
        )
    }

    private func plate() -> SceneRect {
        let subject = annotation()
        let resolved = ResolvedPlacement(
            target: subject.target,
            placement: subject.placement!,
            style: .standard
        )
        return resolved.labelBox(
            textSize: LabelMetrics.size(of: subject, style: .standard, measurer: measurer),
            style: .standard
        )
    }

    @Test("Read left to right, the number is on the left")
    func leftToRight() {
        let disc = BadgeGeometry.rect(in: plate(), style: .standard, reading: .leftToRight)
        #expect(disc.raw.center.x < plate().raw.center.x)
    }

    @Test("Read right to left, the number is on the right")
    func rightToLeft() {
        let disc = BadgeGeometry.rect(in: plate(), style: .standard, reading: .rightToLeft)
        #expect(disc.raw.center.x > plate().raw.center.x)
    }

    @Test("The disc stays inside the plate either way")
    func staysInside() {
        for reading in ReadingDirection.allCases {
            let disc = BadgeGeometry.rect(in: plate(), style: .standard, reading: reading)
            #expect(plate().raw.contains(disc.raw), "the disc is outside the plate when \(reading)")
            #expect(disc.raw.width == StyleTokens.standard.badgeDiameter)
        }
    }

    @Test("The words are clear of the disc either way")
    func wordsClearOfDisc() throws {
        for reading in ReadingDirection.allCases {
            let scene = Scene(
                canvas: Self.canvas,
                background: nil,
                annotations: [annotation()],
                style: .standard
            )
            let list = DrawListBuilder(measurer: measurer, reading: reading).build(scene)
            let run = try #require(Self.labelRun(in: list, saying: annotation().label))
            let disc = BadgeGeometry.rect(in: plate(), style: .standard, reading: reading)

            let words = SceneRect(
                x: run.baselineOrigin.x,
                y: run.baselineOrigin.y - run.metrics.ascent,
                width: run.metrics.width,
                height: run.metrics.height
            )
            #expect(!Geo.overlaps(words.raw, disc.raw), "the words sit under the disc when \(reading)")
        }
    }

    private static func labelRun(in list: DrawList, saying label: String) -> TextRun? {
        for command in list.commands {
            guard case .text(let run) = command, run.text == label else { continue }
            return run
        }
        return nil
    }
}
