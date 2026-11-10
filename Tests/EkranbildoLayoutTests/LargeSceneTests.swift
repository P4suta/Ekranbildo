import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Large scenes")
struct LargeSceneTests {

    private func problem(count: Int, seed: UInt64 = 1) -> LayoutProblem {
        var random = SplitMix64(seed: seed)
        let annotations = (0..<count).map { index in
            Annotation(
                id: AnnotationID(UInt32(index + 1)),
                target: SceneRect(
                    x: Double(random.next() % 640) + 40,
                    y: Double(random.next() % 420) + 40,
                    width: Double(random.next() % 50) + 24,
                    height: Double(random.next() % 26) + 18
                ),
                label: "Item \(index + 1)",
                placement: nil
            )
        }
        return LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 760, height: 520),
            style: .standard,
            annotations: annotations,
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    @Test("A scene past the exact limit still places everything", arguments: [9, 12, 16])
    func placesEverything(_ count: Int) {
        let subject = problem(count: count)
        let solution = ExactSolver().solve(subject, budget: .standard)
        #expect(solution.assignments.count + solution.unplaced.count == count)
    }

    @Test("A large scene is still feasible", arguments: [9, 12])
    func remainsFeasible(_ count: Int) {
        let subject = problem(count: count)
        let solution = ExactSolver().solve(subject, budget: .standard)
        let violations = solution.violations(
            of: HardConstraints.standard(style: subject.style),
            in: subject
        )
        #expect(violations.isEmpty, "violated: \(violations.map(\.name))")
    }

    @Test("A large scene solves the same way every time")
    func reproducible() {
        let subject = problem(count: 12)
        #expect(isReproducible { ExactSolver().solve(subject, budget: .standard).assignments })
    }

    @Test("Refinement never produces a worse answer than greedy", arguments: [9, 11, 14])
    func neverWorseThanGreedy(_ count: Int) {
        let subject = problem(count: count, seed: UInt64(count))
        let comparator = LexicographicComparator()

        let refined = ExactSolver().solve(subject, budget: .standard)
        let greedyOnly = ExactSolver()
            .solve(subject, budget: SolverBudget(refinementSweeps: 0))

        #expect(
            comparator.compare(
                refined.score,
                greedyOnly.score,
                tieBreak: .neither
            ) != .orderedDescending,
            "refinement made the answer worse"
        )
    }

    @Test("Refinement improves on greedy at least somewhere in the corpus")
    func improvesSomewhere() {
        let comparator = LexicographicComparator()
        var improved = 0

        for seed in UInt64(1)...6 {
            let subject = problem(count: 12, seed: seed)
            let refined = ExactSolver().solve(subject, budget: .standard)
            let greedyOnly = ExactSolver().solve(subject, budget: SolverBudget(refinementSweeps: 0))
            if comparator.compare(
                refined.score,
                greedyOnly.score,
                tieBreak: .neither
            ) == .orderedAscending {
                improved += 1
            }
        }
        #expect(improved > 0, "refinement never improved on greedy across six scenes")
    }

    @Test("Refinement terminates well inside its sweep budget")
    func terminates() {
        let subject = problem(count: 14)
        let solution = ExactSolver().solve(subject, budget: .standard)
        #expect(solution.refinementSweepsUsed < SolverBudget.standard.refinementSweeps)
    }

    @Test("A completed exact search is never beaten by refinement")
    func exactIsAtLeastAsGood() {
        let comparator = LexicographicComparator()
        var compared = 0

        for count in 3...6 {
            let subject = problem(count: count, seed: UInt64(count) * 7)
            let exact = ExactSolver().solve(subject, budget: .standard)
            guard exact.isOptimal else { continue }
            compared += 1

            let approximate = ExactSolver().solve(subject, budget: SolverBudget(exactSolveLimit: 0))
            #expect(
                comparator.compare(
                    exact.score,
                    approximate.score,
                    tieBreak: .neither
                ) != .orderedDescending,
                "the approximate answer beat a completed exact search at \(count) annotations"
            )
        }
        #expect(compared > 0, "no exact search completed, so nothing was checked")
    }

    @Test("Optimality is claimed only when the search finished")
    func optimalityIsClaimedHonestly() {
        let small = problem(count: 3, seed: 21)
        #expect(ExactSolver().solve(small, budget: .standard).isOptimal)

        let starved = ExactSolver()
            .solve(small, budget: SolverBudget(maxPairEvaluations: 1))
        #expect(!starved.isOptimal)

        #expect(!ExactSolver().solve(problem(count: 12), budget: .standard).isOptimal)
    }

    @Test("Search cost grows at the rate the budget was set against")
    func searchCostGrowth() {
        var previous = 0
        for count in 3...5 {
            let subject = problem(count: count, seed: 4)
            let solution = ExactSolver().solve(subject, budget: SolverBudget(maxSearchNodes: .max))
            let nodes = solution.work.searchNodes

            #expect(nodes > previous, "adding an annotation did not cost more search")
            if previous > 0 {
                #expect(
                    nodes < previous * 24,
                    "cost grew by more than the branching factor at \(count) annotations"
                )
            }
            previous = nodes
        }
    }

    @Test("Most scenes within the exact limit are solved to optimality")
    func mostScenesAreSolvedExactly() {
        var optimal = 0
        var total = 0
        for count in 5...7 {
            for seed in UInt64(1)...2 {
                let subject = problem(count: count, seed: seed &* 11 &+ UInt64(count))
                total += 1
                if ExactSolver().solve(subject, budget: .standard).isOptimal { optimal += 1 }
            }
        }
        #expect(optimal * 4 >= total * 3, "only \(optimal) of \(total) scenes solved exactly")
    }
}
