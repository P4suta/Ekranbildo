struct BranchAndBound: Sendable {
    let problem: LayoutProblem
    let constraints: [any HardConstraint]
    let comparator: LexicographicComparator
    let aggregator: ScoreAggregator
    let budget: SolverBudget
    let candidates: [[ScoredCandidate]]
    let indices: [Int]

    struct Outcome {
        let chosen: [ScoredCandidate]
        let sweepsUsed: Int
        let isOptimal: Bool
    }

    func run(work: inout WorkUnitCounters) -> Outcome {
        guard !indices.isEmpty else {
            return Outcome(chosen: [], sweepsUsed: 0, isOptimal: true)
        }

        let pairs = PairTable(
            problem: problem,
            constraints: constraints,
            aggregator: aggregator,
            candidates: candidates,
            indices: indices,
            work: &work
        )

        if indices.count <= budget.exactSolveLimit {
            var state = SearchState(
                floors: floors(),
                pairFloors: pairs.outstandingFloors(),
                pairs: pairs
            )
            explore(depth: 0, state: &state, work: &work)
            if let best = state.best {
                return Outcome(
                    chosen: best.map { candidates[indices[$0.position]][$0.option] },
                    sweepsUsed: 0,
                    isOptimal: !state.exhaustedBudget
                )
            }
        }

        let start = greedy(pairs)
        let search = LocalSearch(
            comparator: comparator,
            budget: budget,
            candidates: candidates,
            indices: indices,
            pairs: pairs
        )
        let refined = search.refine(start, work: &work)
        return Outcome(
            chosen: refined.choices.map { candidates[indices[$0.position]][$0.option] },
            sweepsUsed: refined.made,
            isOptimal: false
        )
    }

    private func scored(_ choice: Choice) -> ScoredCandidate {
        candidates[indices[choice.position]][choice.option]
    }

    private func floors() -> [GroupScores] {
        var floors = [GroupScores](repeating: GroupScores(), count: indices.count + 1)
        for depth in stride(from: indices.count - 1, through: 0, by: -1) {
            var floor = floors[depth + 1]
            let options = candidates[indices[depth]]
            for group in ObjectiveGroup.allCases {
                var lowest = Double.infinity
                for option in options {
                    lowest = min(lowest, option.unary[group])
                }
                floor[group] += lowest.isFinite ? lowest : 0
            }
            floors[depth] = floor
        }
        return floors
    }

    private struct SearchState {
        let floors: [GroupScores]
        let pairFloors: [GroupScores]
        let pairs: PairTable
        var assigned: [Choice] = []
        var unaryTotal = GroupScores()
        var pairTotal = GroupScores()
        var best: [Choice]?
        var bestScore: GroupScores?
        var exhaustedBudget = false
    }

    private func explore(depth: Int, state: inout SearchState, work: inout WorkUnitCounters) {
        work.searchNodes += 1

        guard depth < indices.count else {
            recordComplete(&state)
            return
        }

        for option in candidates[indices[depth]].indices {
            guard
                work.searchNodes <= budget.maxSearchNodes,
                work.pairEvaluations <= budget.maxPairEvaluations
            else {
                state.exhaustedBudget = true
                return
            }
            let choice = Choice(position: depth, option: option)
            guard let addition = pairAddition(for: choice, against: state.assigned, in: state.pairs)
            else { continue }

            let nextUnary = state.unaryTotal.adding(scored(choice).unary)
            let nextPairs = state.pairTotal.adding(addition)

            let floor = state.floors[depth + 1].adding(state.pairFloors[depth + 1])
            if isPruned(
                unary: nextUnary,
                pairs: nextPairs,
                floor: floor,
                against: state.bestScore,
                work: &work
            ) {
                continue
            }

            let savedUnary = state.unaryTotal
            let savedPairs = state.pairTotal
            state.unaryTotal = nextUnary
            state.pairTotal = nextPairs
            state.assigned.append(choice)

            explore(depth: depth + 1, state: &state, work: &work)

            state.assigned.removeLast()
            state.unaryTotal = savedUnary
            state.pairTotal = savedPairs
        }
    }

    private func pairAddition(
        for choice: Choice,
        against assigned: [Choice],
        in pairs: PairTable
    ) -> GroupScores? {
        var addition = GroupScores()
        for placed in assigned {
            let key = PairKey(
                outerPosition: placed.position,
                innerPosition: choice.position,
                outerOption: placed.option,
                innerOption: choice.option
            )
            guard pairs.isFeasible(key) else { return nil }
            addition.add(pairs.score(key))
        }
        return addition
    }

    private func isPruned(
        unary: GroupScores,
        pairs: GroupScores,
        floor: GroupScores,
        against incumbent: GroupScores?,
        work: inout WorkUnitCounters
    ) -> Bool {
        guard let incumbent else { return false }
        let bound = unary.adding(pairs).adding(floor)
        guard comparator.compare(bound, incumbent, tieBreak: .neither) == .orderedDescending
        else { return false }
        work.prunedBranches += 1
        return true
    }

    private func recordComplete(_ state: inout SearchState) {
        let total = state.unaryTotal.adding(state.pairTotal)
        if let existing = state.bestScore,
            comparator.compare(total, existing, tieBreak: .neither) != .orderedAscending
        {
            return
        }
        state.bestScore = total
        state.best = state.assigned
    }

    private func greedy(_ pairs: PairTable) -> [Choice] {
        var chosen: [Choice] = []
        for position in indices.indices {
            let options = candidates[indices[position]]
            guard !options.isEmpty else { continue }
            let pick =
                options.indices.first { option in
                    chosen.allSatisfy { placed in
                        pairs.isFeasible(
                            PairKey(
                                outerPosition: placed.position,
                                innerPosition: position,
                                outerOption: placed.option,
                                innerOption: option
                            )
                        )
                    }
                } ?? 0
            chosen.append(Choice(position: position, option: pick))
        }
        return chosen
    }
}
