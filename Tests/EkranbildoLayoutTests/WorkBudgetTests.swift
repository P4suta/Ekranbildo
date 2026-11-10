import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Work budget")
struct WorkBudgetTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "solver")

    private func problem(_ targets: [SceneRect]) -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 320),
            style: .standard,
            annotations: targets.enumerated().map { index, rect in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: rect,
                    label: "Label \(index + 1)",
                    placement: nil
                )
            },
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    @Test("The work a solve costs is unchanged")
    func workIsUnchanged() throws {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 260, y: 150, width: 44, height: 44),
            SceneRect(x: 360, y: 250, width: 60, height: 28),
        ])
        let work = ExactSolver().solve(subject, budget: .standard).work

        let report = """
            candidatesGenerated \(work.candidatesGenerated)
            unaryEvaluations \(work.unaryEvaluations)
            pairEvaluations \(work.pairEvaluations)
            searchNodes \(work.searchNodes)
            prunedBranches \(work.prunedBranches)
            """
        let result = try goldens.compare(report, named: "three-annotations.work")
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("The work a cramped solve costs is unchanged")
    func crampedWorkIsUnchanged() throws {
        let subject = LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 220, height: 170),
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 30, y: 30, width: 50, height: 26),
                    label: "One",
                    placement: nil
                ),
                Annotation(
                    id: AnnotationID(2),
                    target: SceneRect(x: 140, y: 110, width: 50, height: 26),
                    label: "Two",
                    placement: nil
                ),
                Annotation(
                    id: AnnotationID(3),
                    target: SceneRect(x: 140, y: 30, width: 50, height: 26),
                    label: "Three",
                    placement: nil
                ),
            ],
            measurer: TabulatedTextMeasurer.uniform()
        )
        let work = ExactSolver().solve(subject, budget: .standard).work

        let report = """
            candidatesGenerated \(work.candidatesGenerated)
            unaryEvaluations \(work.unaryEvaluations)
            pairEvaluations \(work.pairEvaluations)
            searchNodes \(work.searchNodes)
            prunedBranches \(work.prunedBranches)
            """
        let result = try goldens.compare(report, named: "cramped.work")
        #expect(result.isAcceptable, "\(result.message)")
    }
}

@Suite("Relaxation ladder")
struct RelaxationLadderTests {

    private var subject: LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 400, height: 300),
            style: .standard,
            annotations: [],
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    @Test("Nothing is given up at the first rung")
    func rungZeroKeepsEverything() {
        let all = HardConstraints.standard(style: subject.style).map(\.identifier)
        #expect(ExactSolver.constraints(for: subject, atRung: 0).map(\.identifier) == all)
        #expect(ExactSolver.relaxedConstraints(for: subject, atRung: 0).isEmpty)
    }

    @Test("The label gap is the first thing given up")
    func rungOneRelaxesTheGap() {
        let relaxed = ExactSolver.relaxedConstraints(for: subject, atRung: 1)
        #expect(relaxed == [ConstraintID("labelsAreSeparated")])
        #expect(
            !ExactSolver.constraints(for: subject, atRung: 1)
                .map(\.identifier)
                .contains(ConstraintID("labelsAreSeparated"))
        )
    }

    @Test("Crossing leaders are allowed at the second rung")
    func rungTwoAllowsCrossings() {
        let relaxed = ExactSolver.relaxedConstraints(for: subject, atRung: 2)
        #expect(relaxed.contains(ConstraintID("leadersDoNotCross")))
        #expect(relaxed.contains(ConstraintID("leaderClearOfOtherLabels")))
    }

    @Test("Containment and target clearance survive every rung")
    func someConstraintsAreNeverRelaxed() {
        for rung in 0...5 {
            let kept = ExactSolver.constraints(for: subject, atRung: rung).map(\.identifier)
            #expect(kept.contains(ConstraintID("labelInsideCanvas")))
            #expect(kept.contains(ConstraintID("labelClearOfTargets")))
        }
    }

    @Test("The ladder only ever gives more away")
    func ladderIsMonotone() {
        var previous: Set<ConstraintID> = []
        for rung in 0...5 {
            let relaxed = Set(ExactSolver.relaxedConstraints(for: subject, atRung: rung))
            #expect(previous.isSubset(of: relaxed), "rung \(rung) took back a relaxation")
            previous = relaxed
        }
    }
}
