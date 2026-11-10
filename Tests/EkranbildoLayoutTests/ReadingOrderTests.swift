import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Reading order")
struct ReadingOrderTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func annotations(_ count: Int) -> [Annotation] {
        (0..<count).map { index in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: SceneRect(
                    x: 40 + Double(index) * 110, y: 140, width: 30, height: 20),
                label: "Step \(index + 1)",
                placement: nil,
                badge: BadgeNumber(index + 1)
            )
        }
    }

    private func problem(_ direction: ReadingDirection, count: Int = 3) -> LayoutProblem {
        LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: annotations(count),
            measurer: TabulatedTextMeasurer.uniform(),
            reading: direction
        )
    }

    @Test("Left to right is what a problem reads as unless it says otherwise")
    func defaultDirection() {
        let problem = LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: annotations(1),
            measurer: TabulatedTextMeasurer.uniform()
        )
        #expect(problem.reading == .leftToRight)
    }

    @Test("The leading side is the one a reader starts from")
    func leadingSide() {
        #expect(ReadingDirection.leftToRight.leading == .w)
        #expect(ReadingDirection.rightToLeft.leading == .e)
        #expect(ReadingDirection.leftToRight.trailing == .e)
        #expect(ReadingDirection.rightToLeft.trailing == .w)
    }

    @Test("Reading order runs the way the reader reads")
    func order() {
        let ltr = problem(.leftToRight).readingOrder
        let rtl = problem(.rightToLeft).readingOrder
        #expect(ltr == [0, 1, 2])
        #expect(rtl == [2, 1, 0])
    }

    @Test("Rows are read before columns")
    func rowsFirst() {
        let stacked = LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 300, y: 40, width: 30, height: 20),
                    label: "Upper right",
                    placement: nil
                ),
                Annotation(
                    id: AnnotationID(2),
                    target: SceneRect(x: 40, y: 200, width: 30, height: 20),
                    label: "Lower left",
                    placement: nil
                ),
            ],
            measurer: TabulatedTextMeasurer.uniform(),
            reading: .leftToRight
        )
        #expect(stacked.readingOrder == [0, 1], "the upper one is read first")
    }

    @Test("One annotation is read first whichever way the page runs")
    func single() {
        #expect(problem(.leftToRight, count: 1).readingOrder == [0])
        #expect(problem(.rightToLeft, count: 1).readingOrder == [0])
    }

    @Test("Nothing to read is no order rather than a failure")
    func none() {
        #expect(problem(.leftToRight, count: 0).readingOrder.isEmpty)
    }

    @Test("Reading a mirrored page the other way gives the mirrored order")
    func mirrors() {
        let ltr = problem(.leftToRight)
        let rtl = problem(.rightToLeft)
        #expect(ltr.readingOrder == rtl.readingOrder.reversed())
    }

    @Test("Reading direction does not change what a placement costs")
    func costsAreUnchanged() {
        let ltr = problem(.leftToRight)
        let rtl = problem(.rightToLeft)
        let area = SceneRect(x: 0, y: 0, width: 200, height: 300)
        #expect(ltr.field.meanCost(in: area) == rtl.field.meanCost(in: area))
    }

    @Test("Working out the order is reproducible")
    func reproducible() {
        let subject = problem(.rightToLeft)
        #expect(isReproducible { subject.readingOrder })
    }
}

@Suite("Mirrored reading")
struct MirroredReadingTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func annotations(_ targets: [SceneRect]) -> [Annotation] {
        targets.enumerated().map { index, target in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: target,
                label: "Label",
                placement: nil
            )
        }
    }

    private func mirrored(_ rect: SceneRect) -> SceneRect {
        SceneRect(
            x: Self.canvas.raw.width - rect.maxX,
            y: rect.minY,
            width: rect.raw.width,
            height: rect.raw.height
        )
    }

    private func problem(_ targets: [SceneRect], _ reading: ReadingDirection) -> LayoutProblem {
        LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: annotations(targets),
            measurer: TabulatedTextMeasurer.uniform(),
            reading: reading
        )
    }

    private func solve(_ targets: [SceneRect], _ reading: ReadingDirection) -> LayoutSolution {
        ExactSolver().solve(problem(targets, reading), budget: .standard)
    }

    private static let targets = [
        SceneRect(x: 60, y: 120, width: 40, height: 24),
        SceneRect(x: 250, y: 180, width: 40, height: 24),
    ]

    @Test("A mirrored page read the other way is exactly as good")
    func mirrorIsAsGood() {
        let original = solve(Self.targets, .leftToRight)
        let flipped = solve(Self.targets.map(mirrored), .rightToLeft)
        let explained = LexicographicComparator().explain(
            original.score,
            flipped.score,
            tieBreak: .neither
        )
        let deciding = explained.decidingGroup.map(String.init(describing:)) ?? "nothing"
        #expect(
            explained.decidingGroup == nil,
            "\(deciding) told them apart: \(original.score) against \(flipped.score)"
        )
    }

    @Test("A mirrored page is never the worse answer")
    func mirrorIsNeverWorse() {
        let original = solve(Self.targets, .leftToRight)
        let flipped = solve(Self.targets.map(mirrored), .rightToLeft)
        #expect(
            LexicographicComparator().compare(
                flipped.score,
                original.score,
                tieBreak: TieBreak(CandidateID(0), CandidateID(1))
            ) != .orderedDescending
        )
    }

    @Test("A mirrored page gives nothing up that the original did not")
    func mirrorRelaxesNoMore() {
        let original = solve(Self.targets, .leftToRight)
        let flipped = solve(Self.targets.map(mirrored), .rightToLeft)
        #expect(original.relaxationRung == flipped.relaxationRung)
        #expect(original.unplaced.count == flipped.unplaced.count)
    }

    @Test("Both pages are solved to optimality")
    func bothOptimal() {
        #expect(solve(Self.targets, .leftToRight).isOptimal)
        #expect(solve(Self.targets.map(mirrored), .rightToLeft).isOptimal)
    }
}
