struct PairKey: Hashable, Sendable {
    let outerPosition: Int
    let innerPosition: Int
    let outerOption: Int
    let innerOption: Int

    var reversed: Self {
        Self(
            outerPosition: innerPosition,
            innerPosition: outerPosition,
            outerOption: innerOption,
            innerOption: outerOption
        )
    }
}

struct PairTable: Sendable {
    private let positions: Int
    private let stride: Int
    private let scores: [Double]
    private let floors: [GroupScores]
    private let feasible: [Bool]

    private static let groupCount = ObjectiveGroup.allCases.count

    init(
        problem: LayoutProblem,
        constraints: [any HardConstraint],
        aggregator: ScoreAggregator,
        candidates: [[ScoredCandidate]],
        indices: [Int],
        work: inout WorkUnitCounters
    ) {
        let positions = indices.count
        let stride = candidates.map(\.count).max() ?? 0
        self.positions = positions
        self.stride = stride

        let cells = positions * positions * stride * stride
        var scores = [Double](repeating: 0, count: cells * Self.groupCount)
        var feasible = [Bool](repeating: true, count: cells)
        var floors = [GroupScores](repeating: GroupScores(), count: positions * positions)

        func offset(_ key: PairKey) -> Int {
            ((key.outerPosition * positions + key.innerPosition) * stride + key.outerOption) * stride
                + key.innerOption
        }

        for outer in 0..<positions {
            for inner in (outer + 1)..<positions {
                var lowest = GroupScores()
                var seen = false

                for (outerOption, first) in candidates[indices[outer]].enumerated() {
                    for (innerOption, second) in candidates[indices[inner]].enumerated() {
                        let key = PairKey(
                            outerPosition: outer,
                            innerPosition: inner,
                            outerOption: outerOption,
                            innerOption: innerOption
                        )

                        var allowed = true
                        for constraint in constraints
                        where !constraint.isSatisfied(first.candidate, second.candidate, in: problem) {
                            allowed = false
                        }
                        feasible[offset(key)] = allowed
                        feasible[offset(key.reversed)] = allowed

                        work.pairEvaluations += aggregator.pairTerms.count
                        let pair = aggregator.pair(first.candidate, second.candidate, in: problem)
                        for group in ObjectiveGroup.allCases {
                            scores[offset(key) * Self.groupCount + group.rawValue] = pair[group]
                            scores[offset(key.reversed) * Self.groupCount + group.rawValue] = pair[group]
                        }

                        guard allowed else { continue }
                        if seen {
                            for group in ObjectiveGroup.allCases {
                                lowest[group] = min(lowest[group], pair[group])
                            }
                        } else {
                            lowest = pair
                            seen = true
                        }
                    }
                }
                floors[outer * positions + inner] = lowest
                floors[inner * positions + outer] = lowest
            }
        }

        self.scores = scores
        self.feasible = feasible
        self.floors = floors
    }

    private func offset(_ key: PairKey) -> Int {
        ((key.outerPosition * positions + key.innerPosition) * stride + key.outerOption) * stride
            + key.innerOption
    }

    func isFeasible(_ key: PairKey) -> Bool {
        feasible[offset(key)]
    }

    func score(_ key: PairKey) -> GroupScores {
        let base = offset(key) * Self.groupCount
        var result = GroupScores()
        for group in ObjectiveGroup.allCases {
            result[group] = scores[base + group.rawValue]
        }
        return result
    }

    func outstandingFloors() -> [GroupScores] {
        (0...positions).map { depth in
            var total = GroupScores()
            for outer in 0..<positions {
                for inner in max(outer + 1, depth)..<positions {
                    total.add(floors[outer * positions + inner])
                }
            }
            return total
        }
    }
}
