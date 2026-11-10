import EkranbildoGeometry

struct ScoredCandidate: Sendable {
    let candidate: LayoutCandidate
    let unary: GroupScores
}

struct ScoreAggregator: Sendable {
    let unaryTerms: [any UnaryScoreTerm]
    let pairTerms: [any PairScoreTerm]

    func unary(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> GroupScores {
        average(
            over: unaryTerms.map { ($0.group, $0.evaluate(candidate, in: problem).value) }
        )
    }

    func pair(
        _ first: LayoutCandidate,
        _ second: LayoutCandidate,
        in problem: LayoutProblem
    ) -> GroupScores {
        average(
            over: pairTerms.map { ($0.group, $0.evaluate(first, second, in: problem).value) }
        )
    }

    func breakdown(_ candidate: LayoutCandidate, in problem: LayoutProblem) -> [TermScore] {
        unaryTerms.map { term in
            TermScore(
                term: term.identifier,
                group: term.group,
                value: term.evaluate(candidate, in: problem)
            )
        }
    }

    private func average(over measurements: [(ObjectiveGroup, Double)]) -> GroupScores {
        var sums = [DeterministicSum](
            repeating: DeterministicSum(),
            count: ObjectiveGroup.allCases.count
        )
        var counts = [Int](repeating: 0, count: ObjectiveGroup.allCases.count)
        for (group, value) in measurements {
            sums[group.rawValue].add(value)
            counts[group.rawValue] += 1
        }

        var scores = GroupScores()
        for group in ObjectiveGroup.allCases where counts[group.rawValue] > 0 {
            scores[group] = sums[group.rawValue].value() / Double(counts[group.rawValue])
        }
        return scores
    }
}

extension GroupScores {
    mutating func add(_ other: GroupScores) {
        readability += other.readability
        targetClarity += other.targetClarity
        clearance += other.clearance
        consistency += other.consistency
        aesthetics += other.aesthetics
    }

    func adding(_ other: GroupScores) -> GroupScores {
        var copy = self
        copy.add(other)
        return copy
    }
}
