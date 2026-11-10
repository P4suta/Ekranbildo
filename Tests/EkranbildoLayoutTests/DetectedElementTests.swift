import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import Testing

@Suite("Detected elements")
struct DetectedElementTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private static let panels = [
        SceneRect(x: 0, y: 0, width: 400, height: 90),
        SceneRect(x: 0, y: 210, width: 400, height: 90),
        SceneRect(x: 300, y: 0, width: 100, height: 300),
    ]

    private func elements(_ rects: [SceneRect]) -> [ScreenElement] {
        rects.map { ScreenElement(rect: $0, kind: .surface, confidence: 1, provenance: .given) }
    }

    private func problem(elements: [ScreenElement]) -> LayoutProblem {
        LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 190, y: 140, width: 20, height: 20),
                    label: "Open",
                    placement: nil
                )
            ],
            measurer: TabulatedTextMeasurer.uniform(),
            elements: elements
        )
    }

    private func labelRect(_ subject: LayoutProblem) -> SceneRect? {
        let solution = ExactSolver().solve(subject, budget: .standard)
        guard let placement = solution.assignments.first else { return nil }
        let resolved = ResolvedPlacement(
            target: subject.annotations[0].target,
            placement: placement.placement,
            style: subject.style
        )
        return resolved.labelBox(textSize: subject.textSizes[0], style: subject.style)
    }

    @Test("The label avoids what the detector found")
    func avoidsDetectedElements() throws {
        let placed = try #require(labelRect(problem(elements: elements(Self.panels))))
        for panel in Self.panels {
            #expect(
                !Geo.overlaps(placed.raw, panel.raw),
                "the label sits on \(panel.canonicalText), which detection reported"
            )
        }
    }

    @Test("Without them the same scene answers differently")
    func elementsChangeTheAnswer() throws {
        let withElements = try #require(labelRect(problem(elements: elements(Self.panels))))
        let without = try #require(labelRect(problem(elements: [])))
        #expect(withElements != without)
    }

    @Test("Confidence carries through to the cost")
    func confidenceMatters() {
        let sure = problem(elements: elements(Self.panels))
        let unsure = problem(
            elements: Self.panels.map {
                ScreenElement(rect: $0, kind: .surface, confidence: 0.25, provenance: .given)
            }
        )
        let area = Self.panels[0]
        #expect(unsure.field.meanCost(in: area) < sure.field.meanCost(in: area))
        #expect(unsure.field.meanCost(in: area) > 0)
    }

    @Test("A canvas-sized finding is not an obstacle")
    func backgroundIsNotAnObstacle() {
        let subject = problem(elements: elements([Self.canvas]))
        let corner = SceneRect(x: 0, y: 0, width: 40, height: 40)
        #expect(subject.field.meanCost(in: corner) == 0)
    }
}

@Suite("Saliency")
struct SaliencyFieldTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 200, height: 100)

    private func problem(_ saliency: SaliencyMap) -> LayoutProblem {
        LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 90, y: 40, width: 20, height: 20),
                    label: "Open",
                    placement: nil
                )
            ],
            measurer: TabulatedTextMeasurer.uniform(),
            semantics: SceneSemantics(
                canvas: Self.canvas,
                elements: [],
                saliency: saliency,
                providerVersion: "test"
            )
        )
    }

    @Test("A salient half costs more than an unsalient one")
    func salientAreaCosts() {
        let subject = problem(SaliencyMap(columns: 2, rows: 1, values: [0, 1]))
        let left = SceneRect(x: 0, y: 0, width: 100, height: 100)
        let right = SceneRect(x: 100, y: 0, width: 100, height: 100)
        #expect(subject.field.meanCost(in: left) < subject.field.meanCost(in: right))
        #expect(subject.field.meanCost(in: right) > 0)
    }

    @Test("No saliency is not the same as saliency of zero")
    func emptyMapChangesNothing() {
        let withNone = problem(.empty)
        let withZero = problem(SaliencyMap(columns: 2, rows: 1, values: [0, 0]))
        let area = SceneRect(x: 0, y: 0, width: 200, height: 100)
        #expect(withNone.field.meanCost(in: area) == withZero.field.meanCost(in: area))
    }

    @Test("Saliency is carried on the problem for the inspector to show")
    func carried() {
        let map = SaliencyMap(columns: 2, rows: 1, values: [0.25, 0.75])
        #expect(problem(map).saliency == map)
    }

    @Test("A malformed map is ignored rather than trusted")
    func malformedIgnored() {
        let area = SceneRect(x: 0, y: 0, width: 200, height: 100)
        let broken = problem(SaliencyMap(columns: 8, rows: 8, values: [1]))
        #expect(broken.field.meanCost(in: area) == problem(.empty).field.meanCost(in: area))
    }
}

@Suite("What covering costs")
struct CoverageWeightTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func field(over rect: SceneRect, kind: ScreenElement.Kind) -> Double {
        let problem = LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: [],
            measurer: TabulatedTextMeasurer.uniform(),
            elements: [
                ScreenElement(
                    rect: rect,
                    kind: kind,
                    confidence: 1,
                    provenance: kind == .text ? .textRecognition : .regionAnalysis
                )
            ]
        )
        return problem.field.meanCost(in: rect)
    }

    @Test("Covering words costs more than covering a surface")
    func textCostsMore() {
        let area = SceneRect(x: 100, y: 100, width: 120, height: 20)
        #expect(field(over: area, kind: .text) > field(over: area, kind: .surface))
    }

    @Test("Covering words is not forbidden outright")
    func textIsNotForbidden() {
        let area = SceneRect(x: 100, y: 100, width: 120, height: 20)
        #expect(field(over: area, kind: .text) < 1)
    }

    @Test("A surface still costs something")
    func surfaceCostsSomething() {
        #expect(field(over: SceneRect(x: 100, y: 100, width: 120, height: 20), kind: .surface) > 0)
    }
}

@Suite("Badges through the solver")
struct BadgePreservationTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene(_ numbers: [Int]) -> [Annotation] {
        numbers.enumerated().map { index, number in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: SceneRect(x: 40 + Double(index) * 90, y: 140, width: 30, height: 20),
                label: "Step \(number)",
                placement: nil,
                badge: BadgeNumber(number)
            )
        }
    }

    private func solved(_ annotations: [Annotation]) -> [Annotation] {
        let problem = LayoutProblem(
            canvas: Self.canvas,
            style: .standard,
            annotations: annotations,
            measurer: TabulatedTextMeasurer.uniform()
        )
        return ExactSolver().solve(problem, budget: .standard).applied(to: annotations)
    }

    @Test("Every number comes out as it went in")
    func keepsNumbers() {
        let given = scene([3, 1, 7])
        #expect(solved(given).map(\.badge) == given.map(\.badge))
    }

    @Test("Numbers that run backwards stay backwards")
    func keepsUnusualOrder() {
        let given = scene([9, 5, 1])
        #expect(solved(given).map(\.badge?.value) == [9, 5, 1])
    }

    @Test("An annotation without a number does not acquire one")
    func doesNotInventNumbers() {
        let plain = [
            Annotation(
                id: AnnotationID(1),
                target: SceneRect(x: 100, y: 140, width: 30, height: 20),
                label: "Plain",
                placement: nil
            )
        ]
        #expect(solved(plain).allSatisfy { $0.badge == nil })
    }

    @Test("Solving still places everything")
    func stillSolves() {
        #expect(solved(scene([1, 2, 3])).allSatisfy { $0.placement != nil })
    }
}
