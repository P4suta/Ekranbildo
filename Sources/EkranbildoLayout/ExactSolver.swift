import EkranbildoCore
import EkranbildoGeometry

public struct ExactSolver: LayoutSolving {
    private let generator: any CandidateGenerating
    private let comparator: LexicographicComparator
    private let aggregator: ScoreAggregator

    public var version: String { "exact-1" }

    public init(
        generator: any CandidateGenerating = GridCandidateGenerator(),
        comparator: LexicographicComparator = LexicographicComparator(),
        unaryTerms: [any UnaryScoreTerm] = ScoreTerms.unary,
        pairTerms: [any PairScoreTerm] = ScoreTerms.pair
    ) {
        self.generator = generator
        self.comparator = comparator
        aggregator = ScoreAggregator(unaryTerms: unaryTerms, pairTerms: pairTerms)
    }

    public func solve(_ problem: LayoutProblem, budget: SolverBudget) -> LayoutSolution {
        var work = WorkUnitCounters()
        guard !problem.annotations.isEmpty else { return .empty }

        let feasible = findFeasibleCandidates(problem, budget: budget, work: &work)
        let (solvable, unplaced) = partition(problem, candidates: feasible.candidates)

        let outcome = BranchAndBound(
            problem: problem,
            constraints: Self.constraints(for: problem, atRung: feasible.rung),
            comparator: comparator,
            aggregator: aggregator,
            budget: budget,
            candidates: feasible.candidates,
            indices: solvable
        ).run(work: &work)
        let chosen = outcome.chosen

        return LayoutSolution(
            assignments: chosen.map {
                LayoutAssignment(
                    annotationID: $0.candidate.annotationID,
                    annotationIndex: $0.candidate.annotationIndex,
                    placement: $0.candidate.placement,
                    candidateID: $0.candidate.id
                )
            },
            unplaced: unplaced,
            score: jointScore(of: chosen, in: problem),
            relaxationRung: feasible.rung,
            work: work,
            trace: DecisionTrace(
                decisions: decisions(
                    for: chosen,
                    from: feasible.candidates,
                    indices: solvable,
                    in: problem,
                    recording: budget.candidatesRecordedPerAnnotation
                ),
                relaxationRung: feasible.rung,
                relaxedConstraints: Self.relaxedConstraints(for: problem, atRung: feasible.rung)
            ),
            refinementSweepsUsed: outcome.sweepsUsed,
            isOptimal: outcome.isOptimal
        )
    }

    private struct FeasibleSet {
        let candidates: [[ScoredCandidate]]
        let rung: Int
    }

    private func findFeasibleCandidates(
        _ problem: LayoutProblem,
        budget: SolverBudget,
        work: inout WorkUnitCounters
    ) -> FeasibleSet {
        let deepestRung = Self.deepestRung(for: problem)
        var deepest = FeasibleSet(candidates: [], rung: 0)
        for rung in 0...deepestRung {
            let candidates = prune(
                problem,
                budget: budget,
                constraints: Self.constraints(for: problem, atRung: rung),
                work: &work
            )
            deepest = FeasibleSet(candidates: candidates, rung: rung)
            if candidates.allSatisfy({ !$0.isEmpty }) { return deepest }
        }
        return deepest
    }

    private func prune(
        _ problem: LayoutProblem,
        budget: SolverBudget,
        constraints: [any HardConstraint],
        work: inout WorkUnitCounters
    ) -> [[ScoredCandidate]] {
        problem.annotations.indices.map { index in
            let generated = generator.generate(forAnnotationAt: index, in: problem)
            work.candidatesGenerated += generated.count

            var feasible: [ScoredCandidate] = []
            for candidate in generated
            where constraints.allSatisfy({ $0.isSatisfied(candidate, in: problem) }) {
                work.unaryEvaluations += aggregator.unaryTerms.count
                feasible.append(
                    ScoredCandidate(candidate: candidate, unary: aggregator.unary(candidate, in: problem))
                )
            }

            feasible.sort { lhs, rhs in
                comparator.compare(
                    lhs.unary,
                    rhs.unary,
                    tieBreak: TieBreak(lhs.candidate.id, rhs.candidate.id)
                ) == .orderedAscending
            }
            return Array(feasible.prefix(budget.candidatesPerAnnotation))
        }
    }

    private func partition(
        _ problem: LayoutProblem,
        candidates: [[ScoredCandidate]]
    ) -> (solvable: [Int], unplaced: [UnplacedAnnotation]) {
        var solvable: [Int] = []
        var unplaced: [UnplacedAnnotation] = []
        for index in problem.annotations.indices {
            if candidates[index].isEmpty {
                unplaced.append(
                    UnplacedAnnotation(
                        annotationID: problem.annotations[index].id,
                        reason: "no placement satisfied the constraints, even fully relaxed"
                    )
                )
            } else {
                solvable.append(index)
            }
        }
        return (solvable, unplaced)
    }

    private func jointScore(of chosen: [ScoredCandidate], in problem: LayoutProblem) -> GroupScores {
        var total = GroupScores()
        for item in chosen {
            total.add(item.unary)
        }
        for outer in chosen.indices {
            for inner in (outer + 1)..<chosen.count {
                total.add(aggregator.pair(chosen[outer].candidate, chosen[inner].candidate, in: problem))
            }
        }
        return total
    }

    private func decisions(
        for chosen: [ScoredCandidate],
        from candidates: [[ScoredCandidate]],
        indices: [Int],
        in problem: LayoutProblem,
        recording: Int
    ) -> [AnnotationDecision] {
        indices.enumerated().map { position, index in
            let options = candidates[index]
            let margin = options.count > 1 ? abs(options[1].unary.total - options[0].unary.total) : 0

            let winner = position < chosen.count ? chosen[position] : nil
            let winnerRank = winner.flatMap { picked in
                options.firstIndex { $0.candidate.id == picked.candidate.id }
            }

            var recordedRanks = Array(0..<min(max(0, recording), options.count))
            if let winnerRank, !recordedRanks.contains(winnerRank) {
                recordedRanks.append(winnerRank)
            }
            let recorded = recordedRanks.map { rank in
                let scored = options[rank]
                return CandidateRecord(
                    id: scored.candidate.id,
                    placement: scored.candidate.placement,
                    labelRect: scored.candidate.labelRect,
                    tip: scored.candidate.tip,
                    tail: scored.candidate.tail,
                    groupScores: scored.unary,
                    terms: aggregator.breakdown(scored.candidate, in: problem),
                    rank: rank
                )
            }

            let alternative = options.first { $0.candidate.id != winner?.candidate.id }
            let reason =
                if let winner, let alternative {
                    comparator.explain(
                        winner.unary,
                        alternative.unary,
                        tieBreak: TieBreak(winner.candidate.id, alternative.candidate.id)
                    )
                } else {
                    ComparisonExplanation?.none
                }

            return AnnotationDecision(
                annotationID: options.first?.candidate.annotationID ?? AnnotationID(0),
                consideredCount: options.count,
                winner: winner?.candidate.id,
                margin: margin,
                runnerUp: alternative?.candidate.id,
                winnerRank: winnerRank,
                overrodeUnaryFavourite: (winnerRank ?? 0) > 0,
                candidates: recorded,
                winReason: reason
            )
        }
    }

    private static func deepestRung(for problem: LayoutProblem) -> Int {
        HardConstraints.standard(style: problem.style).compactMap(\.relaxableAtRung).max() ?? 0
    }

    static func constraints(for problem: LayoutProblem, atRung rung: Int) -> [any HardConstraint] {
        HardConstraints.standard(style: problem.style).filter { constraint in
            guard let relaxable = constraint.relaxableAtRung else { return true }
            return relaxable > rung
        }
    }

    static func relaxedConstraints(for problem: LayoutProblem, atRung rung: Int) -> [ConstraintID] {
        HardConstraints.standard(style: problem.style)
            .filter { constraint in
                guard let relaxable = constraint.relaxableAtRung else { return false }
                return relaxable <= rung
            }
            .map(\.identifier)
    }
}

extension LayoutSolution {
    static let empty = LayoutSolution(
        assignments: [],
        unplaced: [],
        score: GroupScores(),
        relaxationRung: 0,
        work: WorkUnitCounters(),
        trace: DecisionTrace(decisions: [], relaxationRung: 0, relaxedConstraints: []),
        isOptimal: true
    )
}
