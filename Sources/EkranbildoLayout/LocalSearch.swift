struct Choice: Equatable, Sendable {
    let position: Int
    let option: Int
}

struct Sweeps {
    let choices: [Choice]
    let made: Int
}

struct LocalSearch: Sendable {
    let comparator: LexicographicComparator
    let budget: SolverBudget
    let candidates: [[ScoredCandidate]]
    let indices: [Int]
    let pairs: PairTable

    private func scored(_ choice: Choice) -> ScoredCandidate {
        candidates[indices[choice.position]][choice.option]
    }

    private func pairAddition(
        for choice: Choice,
        against others: [Choice]
    ) -> GroupScores? {
        var addition = GroupScores()
        for other in others {
            let key = PairKey(
                outerPosition: other.position,
                innerPosition: choice.position,
                outerOption: other.option,
                innerOption: choice.option
            )
            guard pairs.isFeasible(key) else { return nil }
            addition.add(pairs.score(key))
        }
        return addition
    }

    func refine(
        _ start: [Choice],
        work: inout WorkUnitCounters
    ) -> Sweeps {
        guard budget.refinementSweeps > 0, start.count == indices.count else {
            return Sweeps(choices: start, made: 0)
        }

        var current = start
        var sweeps = 0

        while sweeps < budget.refinementSweeps {
            var changed = false
            sweeps += 1

            for position in current.indices {
                guard let better = bestReplacement(at: position, in: current) else {
                    continue
                }
                current[position] = better
                work.refinementMoves += 1
                changed = true
            }

            if !changed { break }
        }
        return Sweeps(choices: current, made: sweeps)
    }

    private func bestReplacement(
        at position: Int,
        in current: [Choice]
    ) -> Choice? {
        let others = current.enumerated().filter { $0.offset != position }.map(\.element)
        var incumbent = current[position]
        var incumbentCost = contextualCost(of: incumbent, against: others)
        var improved = false

        for option in candidates[indices[position]].indices where option != current[position].option {
            let choice = Choice(position: position, option: option)
            guard let addition = pairAddition(for: choice, against: others) else {
                continue
            }
            let cost = scored(choice).unary.adding(addition)
            guard
                comparator.compare(cost, incumbentCost, tieBreak: .neither) == .orderedAscending
            else { continue }
            incumbent = choice
            incumbentCost = cost
            improved = true
        }
        return improved ? incumbent : nil
    }

    private func contextualCost(
        of choice: Choice,
        against others: [Choice]
    ) -> GroupScores {
        var total = scored(choice).unary
        for other in others {
            total.add(
                pairs.score(
                    PairKey(
                        outerPosition: other.position,
                        innerPosition: choice.position,
                        outerOption: other.option,
                        innerOption: choice.option
                    )
                )
            )
        }
        return total
    }
}
