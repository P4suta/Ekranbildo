import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoInspector
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Quality metrics")
struct QualityMetricsTests {

    private func problem(_ targets: [SceneRect], labels: [String]? = nil) -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 320),
            style: .standard,
            annotations: targets.enumerated().map { index, rect in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: rect,
                    label: labels?[index] ?? "Label \(index + 1)",
                    placement: nil
                )
            },
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func measure(_ subject: LayoutProblem) -> QualityMetrics {
        QualityMetrics(
            of: ExactSolver().solve(subject, budget: .standard),
            in: subject
        )
    }

    @Test("A comfortable scene scores clean")
    func comfortableScene() {
        let metrics = measure(
            problem([
                SceneRect(x: 100, y: 80, width: 40, height: 24),
                SceneRect(x: 340, y: 230, width: 50, height: 26),
            ])
        )
        #expect(metrics.annotations == 2)
        #expect(metrics.unplaced == 0)
        #expect(metrics.relaxationRung == 0)
        #expect(metrics.labelCollisions == 0)
        #expect(metrics.leaderCrossings == 0)
        #expect(metrics.labelsOutsideCanvas == 0)
        #expect(metrics.labelsOverTargets == 0)
    }

    @Test("Counts cover every annotation")
    func countsEveryAnnotation() {
        let metrics = measure(
            problem([
                SceneRect(x: 60, y: 60, width: 30, height: 20),
                SceneRect(x: 200, y: 140, width: 30, height: 20),
                SceneRect(x: 380, y: 240, width: 30, height: 20),
            ])
        )
        #expect(metrics.annotations == 3)
        #expect(metrics.placed == 3)
    }

    @Test("Crowded targets score as more ambiguous than spread out ones")
    func ambiguityReflectsCrowding() {
        let spread = measure(
            problem([
                SceneRect(x: 60, y: 60, width: 30, height: 20),
                SceneRect(x: 380, y: 240, width: 30, height: 20),
            ])
        )
        let crowded = measure(
            problem([
                SceneRect(x: 200, y: 150, width: 30, height: 20),
                SceneRect(x: 240, y: 150, width: 30, height: 20),
            ])
        )
        #expect(crowded.worstPointingAmbiguity > spread.worstPointingAmbiguity)
    }

    @Test("Axis-aligned leaders are counted")
    func countsAxisAlignedLeaders() {
        let metrics = measure(problem([SceneRect(x: 200, y: 150, width: 30, height: 20)]))
        #expect(metrics.axisAlignedLeaders >= 0)
        #expect(metrics.axisAlignedLeaders <= metrics.placed)
    }

    @Test("Decision margins are summarised")
    func summarisesMargins() {
        let metrics = measure(
            problem([
                SceneRect(x: 100, y: 80, width: 40, height: 24),
                SceneRect(x: 340, y: 230, width: 50, height: 26),
            ])
        )
        #expect(metrics.minimumDecisionMargin >= 0)
        #expect(metrics.meanDecisionMargin >= metrics.minimumDecisionMargin)
    }

    @Test("An empty scene measures as empty rather than failing")
    func emptyScene() {
        let metrics = measure(problem([]))
        #expect(metrics.annotations == 0)
        #expect(metrics.placed == 0)
        #expect(metrics.meanDecisionMargin == 0)
        #expect(metrics.worstPointingAmbiguity == 0)
    }

    @Test("Metrics render as sorted key-value text for comparison")
    func canonicalText() {
        let text = measure(problem([SceneRect(x: 100, y: 80, width: 40, height: 24)])).canonicalText
        let keys = text.split(separator: "\n").map { $0.split(separator: " ")[0] }
        #expect(keys == keys.sorted())
        #expect(text.contains("labelCollisions"))
    }

    @Test("Measuring the same solve twice gives the same numbers")
    func reproducible() {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 340, y: 230, width: 50, height: 26),
        ])
        #expect(isReproducible { measure(subject).canonicalText })
    }

    @Test("Overlapping labels are counted")
    func countsOverlappingLabels() {
        let target = SceneRect(x: 190, y: 130, width: 20, height: 20)
        let subject = problem([target, target])
        let placement = Placement(direction: .e, leaderLength: 40)
        let broken = LayoutSolution(
            assignments: subject.annotations.enumerated().map { index, annotation in
                LayoutAssignment(
                    annotationID: annotation.id,
                    annotationIndex: index,
                    placement: placement,
                    candidateID: CandidateID(UInt32(index))
                )
            },
            unplaced: [],
            score: GroupScores(),
            relaxationRung: 0,
            work: WorkUnitCounters(),
            trace: DecisionTrace(decisions: [], relaxationRung: 0, relaxedConstraints: [])
        )
        #expect(QualityMetrics(of: broken, in: subject).labelCollisions == 1)
    }

    @Test("Leaders that cross are counted")
    func countsCrossingLeaders() {
        let subject = problem([
            SceneRect(x: 120, y: 100, width: 20, height: 20),
            SceneRect(x: 300, y: 100, width: 20, height: 20),
        ])
        let broken = LayoutSolution(
            assignments: [
                LayoutAssignment(
                    annotationID: AnnotationID(1),
                    annotationIndex: 0,
                    placement: Placement(direction: .se, leaderLength: 180),
                    candidateID: CandidateID(0)
                ),
                LayoutAssignment(
                    annotationID: AnnotationID(2),
                    annotationIndex: 1,
                    placement: Placement(direction: .sw, leaderLength: 180),
                    candidateID: CandidateID(1)
                ),
            ],
            unplaced: [],
            score: GroupScores(),
            relaxationRung: 0,
            work: WorkUnitCounters(),
            trace: DecisionTrace(decisions: [], relaxationRung: 0, relaxedConstraints: [])
        )
        #expect(QualityMetrics(of: broken, in: subject).leaderCrossings == 1)
    }

    @Test("A label pushed off the canvas is counted")
    func countsLabelsOffCanvas() {
        let subject = problem([SceneRect(x: 30, y: 140, width: 20, height: 20)])
        let broken = LayoutSolution(
            assignments: [
                LayoutAssignment(
                    annotationID: AnnotationID(1),
                    annotationIndex: 0,
                    placement: Placement(direction: .w, leaderLength: 200),
                    candidateID: CandidateID(0)
                )
            ],
            unplaced: [],
            score: GroupScores(),
            relaxationRung: 0,
            work: WorkUnitCounters(),
            trace: DecisionTrace(decisions: [], relaxationRung: 0, relaxedConstraints: [])
        )
        #expect(QualityMetrics(of: broken, in: subject).labelsOutsideCanvas == 1)
    }

    @Test("A feasible solution shows no violations")
    func agreesWithTheConstraints() {
        var generator = SplitMix64(seed: 5_150)
        for _ in 0..<15 {
            let count = Int(generator.next() % 3) + 1
            let targets = (0..<count).map { _ in
                SceneRect(
                    x: Double(generator.next() % 380) + 20,
                    y: Double(generator.next() % 240) + 20,
                    width: Double(generator.next() % 50) + 20,
                    height: Double(generator.next() % 30) + 16
                )
            }
            let subject = problem(targets)
            let solution = ExactSolver().solve(subject, budget: .standard)
            guard solution.relaxationRung == 0, solution.unplaced.isEmpty else { continue }

            let metrics = QualityMetrics(of: solution, in: subject)
            #expect(metrics.labelCollisions == 0)
            #expect(metrics.labelsOutsideCanvas == 0)
            #expect(metrics.labelsOverTargets == 0)
        }
    }
}
