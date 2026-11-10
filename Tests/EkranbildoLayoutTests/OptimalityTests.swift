import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoLayout
import Testing

@Suite("Optimality")
struct OptimalityTests {
    private let generator = GridCandidateGenerator(
        directions: [.ne, .se, .sw, .nw],
        leaderLengths: [40, 80]
    )
    private let comparator = LexicographicComparator()
    private let aggregator = ScoreAggregator(
        unaryTerms: ScoreTerms.unary,
        pairTerms: ScoreTerms.pair
    )

    private func problem(_ targets: [SceneRect]) -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 320),
            style: .standard,
            annotations: targets.enumerated().map { index, rect in
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: rect,
                    label: "L\(index + 1)",
                    placement: nil
                )
            },
            measurer: TabulatedTextMeasurer.uniform()
        )
    }

    private func exhaustiveBest(_ subject: LayoutProblem) -> GroupScores? {
        let constraints = ExactSolver.constraints(for: subject, atRung: 0)
        let perAnnotation = subject.annotations.indices.map { index in
            generator.generate(forAnnotationAt: index, in: subject)
                .filter { candidate in
                    constraints.allSatisfy { $0.isSatisfied(candidate, in: subject) }
                }
        }
        guard perAnnotation.allSatisfy({ !$0.isEmpty }) else { return nil }

        var best: GroupScores?
        var current: [LayoutCandidate] = []

        func recurse(_ depth: Int) {
            guard depth < perAnnotation.count else {
                var total = GroupScores()
                for candidate in current {
                    total.add(aggregator.unary(candidate, in: subject))
                }
                for outer in 0..<current.count {
                    for inner in (outer + 1)..<current.count {
                        total.add(aggregator.pair(current[outer], current[inner], in: subject))
                    }
                }
                if let existing = best,
                    comparator.compare(total, existing, tieBreak: .neither)
                        != .orderedAscending
                {
                    return
                }
                best = total
                return
            }

            for candidate in perAnnotation[depth] {
                var feasible = true
                for placed in current {
                    for constraint in constraints
                    where !constraint.isSatisfied(placed, candidate, in: subject) {
                        feasible = false
                    }
                }
                guard feasible else { continue }
                current.append(candidate)
                recurse(depth + 1)
                current.removeLast()
            }
        }
        recurse(0)
        return best
    }

    private func scoreOfSolution(_ subject: LayoutProblem) -> GroupScores? {
        let solution = ExactSolver(generator: generator).solve(subject, budget: .standard)
        guard solution.unplaced.isEmpty, !solution.assignments.isEmpty else { return nil }

        let placed = solution.assignments.map { assignment -> LayoutCandidate in
            let resolved = ResolvedPlacement(
                target: subject.annotations[assignment.annotationIndex].target,
                placement: assignment.placement,
                style: subject.style
            )
            return LayoutCandidate(
                id: assignment.candidateID,
                annotationID: assignment.annotationID,
                annotationIndex: assignment.annotationIndex,
                placement: assignment.placement,
                tip: resolved.tip,
                tail: resolved.tail,
                labelRect: resolved.labelBox(
                    textSize: subject.textSizes[assignment.annotationIndex],
                    style: subject.style
                )
            )
        }

        var total = GroupScores()
        for candidate in placed {
            total.add(aggregator.unary(candidate, in: subject))
        }
        for outer in 0..<placed.count {
            for inner in (outer + 1)..<placed.count {
                total.add(aggregator.pair(placed[outer], placed[inner], in: subject))
            }
        }
        return total
    }

    @Test("The search matches exhaustive enumeration on two annotations")
    func matchesExhaustiveForTwo() throws {
        let subject = problem([
            SceneRect(x: 120, y: 90, width: 50, height: 24),
            SceneRect(x: 300, y: 200, width: 60, height: 30),
        ])
        let exhaustive = try #require(exhaustiveBest(subject))
        let solved = try #require(scoreOfSolution(subject))
        #expect(
            comparator.compare(solved, exhaustive, tieBreak: .neither)
                != .orderedDescending,
            "the search found a worse answer than exhaustive enumeration"
        )
    }

    @Test("The search matches exhaustive enumeration on three annotations")
    func matchesExhaustiveForThree() throws {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 260, y: 150, width: 44, height: 44),
            SceneRect(x: 360, y: 250, width: 60, height: 28),
        ])
        let exhaustive = try #require(exhaustiveBest(subject))
        let solved = try #require(scoreOfSolution(subject))
        #expect(
            comparator.compare(solved, exhaustive, tieBreak: .neither)
                != .orderedDescending,
            "the search found a worse answer than exhaustive enumeration"
        )
    }

    @Test("The search matches exhaustive enumeration across random scenes")
    func matchesExhaustiveAcrossRandomScenes() throws {
        var random = SplitMix64(seed: 90_210)
        var compared = 0

        for _ in 0..<12 {
            let count = Int(random.next() % 2) + 2
            let targets = (0..<count).map { _ in
                SceneRect(
                    x: Double(random.next() % 360) + 40,
                    y: Double(random.next() % 220) + 40,
                    width: Double(random.next() % 50) + 20,
                    height: Double(random.next() % 30) + 16
                )
            }
            let subject = problem(targets)
            guard let exhaustive = exhaustiveBest(subject),
                let solved = scoreOfSolution(subject)
            else { continue }

            compared += 1
            #expect(
                comparator.compare(solved, exhaustive, tieBreak: .neither)
                    != .orderedDescending,
                "the search found a worse answer than exhaustive enumeration"
            )
        }
        #expect(compared > 0, "no scene was comparable, so nothing was actually checked")
    }

    @Test("Every group currently has a candidate that scores zero")
    func floorIsCurrentlyZero() {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 260, y: 150, width: 44, height: 44),
        ])
        let terms = ScoreAggregator(unaryTerms: ScoreTerms.unary, pairTerms: ScoreTerms.pair)
        let candidates = GridCandidateGenerator().generate(forAnnotationAt: 0, in: subject)

        for group in ObjectiveGroup.allCases {
            let lowest = candidates.map { terms.unary($0, in: subject)[group] }.min() ?? 1
            #expect(lowest == 0, "no candidate scores zero in \(group)")
        }
    }

    @Test("The bound prunes")
    func boundPrunes() {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 260, y: 150, width: 44, height: 44),
            SceneRect(x: 360, y: 250, width: 60, height: 28),
        ])
        let solution = ExactSolver().solve(subject, budget: .standard)
        #expect(solution.work.prunedBranches > 0)
        #expect(solution.work.prunedBranches > solution.work.searchNodes)
    }

    @Test("A scene with room to spare is solved without relaxing anything")
    func comfortableSceneKeepsEveryConstraint() {
        let subject = problem([
            SceneRect(x: 100, y: 80, width: 40, height: 24),
            SceneRect(x: 340, y: 240, width: 50, height: 26),
        ])
        let solution = ExactSolver().solve(subject, budget: .standard)
        #expect(solution.relaxationRung == 0)
        #expect(solution.trace.relaxedConstraints.isEmpty)
        #expect(
            solution.violations(of: HardConstraints.standard(style: subject.style), in: subject)
                .isEmpty
        )
    }
}
