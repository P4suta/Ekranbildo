@testable import EkranbildoInspector
import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Counterfactual")
struct CounterfactualTests {
    private let comparator = LexicographicComparator()

    private func scores(
        readability: Double = 0,
        targetClarity: Double = 0,
        clearance: Double = 0,
        consistency: Double = 0,
        aesthetics: Double = 0
    ) -> GroupScores {
        var result = GroupScores()
        result.readability = readability
        result.targetClarity = targetClarity
        result.clearance = clearance
        result.consistency = consistency
        result.aesthetics = aesthetics
        return result
    }

    private func explain(
        preferring wanted: GroupScores,
        over chosen: GroupScores
    ) -> Counterfactual.Answer {
        Counterfactual(comparator: comparator).toPrefer(wanted, over: chosen)
    }

    @Test("A candidate worse in every group cannot be made to win")
    func worseEverywhere() {
        let answer = explain(
            preferring: scores(readability: 0.5, targetClarity: 0.5),
            over: scores(readability: 0.1, targetClarity: 0.1)
        )
        #expect(answer == .impossible)
    }

    @Test("A candidate the same in every group cannot be made to win either")
    func identical() {
        let same = scores(readability: 0.2, clearance: 0.3)
        #expect(explain(preferring: same, over: same) == .impossible)
    }

    @Test("A candidate that already wins needs nothing changed")
    func alreadyWins() {
        let answer = explain(
            preferring: scores(readability: 0.1),
            over: scores(readability: 0.5)
        )
        #expect(answer == .alreadyPreferred)
    }

    @Test("A candidate better further down the order says what must stop deciding")
    func mustSilenceEarlierGroups() throws {
        let answer = explain(
            preferring: scores(readability: 0.3, aesthetics: 0.1),
            over: scores(readability: 0.1, aesthetics: 0.9)
        )
        guard case .widen(let groups) = answer else {
            Issue.record("expected something to widen, got \(answer)")
            return
        }
        #expect(groups.map(\.group) == [.readability])
    }

    @Test("It says how wide a tolerance would have to be")
    func saysHowWide() throws {
        let answer = explain(
            preferring: scores(readability: 0.3, aesthetics: 0.1),
            over: scores(readability: 0.1, aesthetics: 0.9)
        )
        guard case .widen(let groups) = answer, let first = groups.first else {
            Issue.record("expected something to widen, got \(answer)")
            return
        }
        #expect(first.tolerance > 0.3)
        #expect(first.wasTolerance == LexicographicComparator().tolerances[.readability])
    }

    @Test("Widening by what it says does make the candidate win")
    func theAnswerWorks() throws {
        let wanted = scores(readability: 0.3, clearance: 0.2, aesthetics: 0.1)
        let chosen = scores(readability: 0.1, clearance: 0.6, aesthetics: 0.9)

        guard case .widen(let groups) = explain(preferring: wanted, over: chosen) else {
            Issue.record("expected something to widen")
            return
        }

        var values = ObjectiveGroup.allCases.map { LexicographicComparator().tolerances[$0] }
        for change in groups { values[change.group.rawValue] = change.tolerance }

        let widened = LexicographicComparator(tolerances: GroupTolerances(values: values))
        let result = widened.compare(wanted, chosen, tieBreak: TieBreak(CandidateID(1), CandidateID(2)))
        #expect(result == .orderedAscending, "the tolerance it reported did not do it")
    }

    @Test("Every group standing in the way is named")
    func namesEveryGroupInTheWay() throws {
        let answer = explain(
            preferring: scores(readability: 0.3, targetClarity: 0.4, aesthetics: 0.1),
            over: scores(readability: 0.1, targetClarity: 0.2, aesthetics: 0.9)
        )
        guard case .widen(let groups) = answer else {
            Issue.record("expected something to widen, got \(answer)")
            return
        }
        #expect(groups.map(\.group) == [.readability, .targetClarity])
    }

    @Test("A group that was already tied is not asked to change")
    func tiedGroupsAreNotInTheWay() throws {
        let answer = explain(
            preferring: scores(readability: 0.01, targetClarity: 0.4, aesthetics: 0.1),
            over: scores(readability: 0.01, targetClarity: 0.1, aesthetics: 0.9)
        )
        guard case .widen(let groups) = answer else {
            Issue.record("expected something to widen, got \(answer)")
            return
        }
        #expect(groups.map(\.group) == [.targetClarity])
    }

    @Test("The answer reads as a sentence")
    func readable() throws {
        let answer = explain(
            preferring: scores(readability: 0.3, aesthetics: 0.1),
            over: scores(readability: 0.1, aesthetics: 0.9)
        )
        #expect(answer.canonicalText.contains("readability"))
        #expect(Counterfactual.Answer.impossible.canonicalText.contains("nothing"))
        #expect(Counterfactual.Answer.alreadyPreferred.canonicalText.contains("already"))
    }

    @Test("Asking twice gives the same answer")
    func reproducible() {
        let wanted = scores(readability: 0.3, clearance: 0.2, aesthetics: 0.1)
        let chosen = scores(readability: 0.1, clearance: 0.6, aesthetics: 0.9)
        #expect(isReproducible { self.explain(preferring: wanted, over: chosen).canonicalText })
    }
}
