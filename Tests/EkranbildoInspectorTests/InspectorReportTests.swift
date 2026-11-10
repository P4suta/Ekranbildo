import EkranbildoContracts
import EkranbildoCore
import EkranbildoField
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoInspector
import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Inspector report")
struct InspectorReportTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "inspector")

    private func problem() -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 320),
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 100, y: 80, width: 40, height: 24),
                    label: "Search field",
                    placement: nil
                ),
                Annotation(
                    id: AnnotationID(2),
                    target: SceneRect(x: 300, y: 200, width: 60, height: 30),
                    label: "保存",
                    placement: nil
                ),
            ],
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func report() -> String {
        let subject = problem()
        let solution = ExactSolver().solve(subject, budget: .standard)
        return InspectorReport(measurer: TabulatedTextMeasurer.uniform())
            .html(for: subject, solution: solution)
    }

    @Test("The report is a self-contained document")
    func selfContained() {
        let html = report()
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("</html>"))
        #expect(!html.contains("<script src="))
        #expect(!html.contains("<link rel=\"stylesheet\""))
    }

    @Test("The solved layout is shown")
    func showsTheLayout() {
        #expect(report().contains("<svg"))
    }

    @Test("Every annotation gets a section")
    func annotationSections() {
        let html = report()
        #expect(html.contains("Search field"))
        #expect(html.contains("保存"))
    }

    @Test("Candidates are listed with their term scores")
    func candidateTable() {
        let html = report()
        #expect(html.contains("labelClearance"))
        #expect(html.contains("targetAmbiguity"))
        #expect(html.contains("axisAlignment"))
    }

    @Test("The reason the winner won is stated")
    func statesTheReason() {
        #expect(report().contains("decided by"))
    }

    @Test("The cost field is drawn layer by layer")
    func showsFieldLayers() {
        let html = report()
        for layer in FieldLayer.allCases {
            #expect(html.contains(layer.rawValue), "missing layer \(layer.rawValue)")
        }
    }

    @Test("The work the solve cost is reported")
    func showsWork() {
        let html = report()
        #expect(html.contains("searchNodes"))
        #expect(html.contains("prunedBranches"))
    }

    @Test("The relaxation rung is reported")
    func showsRelaxation() {
        #expect(report().contains("rung"))
    }

    @Test("Label text is escaped")
    func escapesLabels() {
        let subject = LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 300, height: 200),
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 100, y: 80, width: 40, height: 24),
                    label: "<script>alert(1)</script> & \"quoted\"",
                    placement: nil
                )
            ],
            measurer: TabulatedTextMeasurer.uniform()
        )
        let solution = ExactSolver().solve(subject, budget: .standard)
        let html = InspectorReport(measurer: TabulatedTextMeasurer.uniform())
            .html(for: subject, solution: solution)

        #expect(!html.contains("<script"))
        #expect(!html.contains("</script"))
        #expect(html.contains("<h2>&lt;script&gt;"))
        #expect(html.contains("&amp;"))
        #expect(html.contains("&quot;"))
    }

    @Test("The report is the same for the same solve")
    func reproducible() {
        #expect(isReproducible(report))
    }

    @Test("The report for the sample scene is unchanged")
    func golden() throws {
        let result = try goldens.compare(report(), named: "two-annotations.html")
        #expect(result.isAcceptable, "\(result.message)")
    }
}
