import EkranbildoGeometry
@testable import EkranbildoInspector
import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Preferences")
struct PreferenceTests {

    private func judgement(_ scene: String, _ first: UInt32, _ second: UInt32, _ verdict: Verdict)
        -> Judgement
    {
        Judgement(
            scene: scene,
            first: CandidateID(first),
            second: CandidateID(second),
            verdict: verdict
        )
    }

    @Test("A solver that always picks what was preferred agrees completely")
    func fullAgreement() {
        let judgements = [
            judgement("a", 1, 2, .first),
            judgement("b", 3, 4, .second),
        ]
        let chosen = Lookup<String, CandidateID>(["a": CandidateID(1), "b": CandidateID(4)])
        let report = PreferenceReport(judgements: judgements, chosen: chosen, tolerance: 0)
        #expect(report.agreement == 1)
    }

    @Test("A solver that always picks the other one agrees about nothing")
    func noAgreement() {
        let judgements = [judgement("a", 1, 2, .first), judgement("b", 3, 4, .second)]
        let chosen = Lookup<String, CandidateID>(["a": CandidateID(2), "b": CandidateID(3)])
        #expect(PreferenceReport(judgements: judgements, chosen: chosen, tolerance: 0).agreement == 0)
    }

    @Test("When somebody saw no difference, either choice agrees")
    func noDifferenceAlwaysAgrees() {
        let judgements = [judgement("a", 1, 2, .noDifference)]
        for picked in [CandidateID(1), CandidateID(2)] {
            let report = PreferenceReport(
                judgements: judgements, chosen: Lookup(["a": picked]), tolerance: 0)
            #expect(report.agreement == 1)
        }
    }

    @Test("A judgement about a scene the solver did not answer is set aside")
    func unanswered() {
        let judgements = [judgement("a", 1, 2, .first), judgement("missing", 3, 4, .first)]
        let report = PreferenceReport(
            judgements: judgements, chosen: Lookup(["a": CandidateID(1)]), tolerance: 0)
        #expect(report.agreement == 1)
        #expect(report.unanswered == 1)
    }

    @Test("Nothing judged is nothing to report rather than a division by zero")
    func nothingJudged() {
        let report = PreferenceReport(judgements: [], chosen: Lookup([:]), tolerance: 0)
        #expect(report.agreement == 0)
        #expect(report.judged == 0)
    }

    @Test("Agreeing about what is indistinguishable is measured")
    func toleranceAgreement() {
        let report = PreferenceReport(
            judgements: [
                judgement("close", 1, 2, .noDifference),
                judgement("clear", 3, 4, .first),
            ],
            chosen: Lookup(["close": CandidateID(1), "clear": CandidateID(3)]),
            tolerance: 0.05,
            margins: Lookup(["close": 0.01, "clear": 0.4])
        )
        #expect(report.toleranceAgreement == 1)
        #expect(report.toleranceJudged == 2)
    }

    @Test("A tolerance that is too wide shows up as disagreement")
    func toleranceTooWide() {
        let report = PreferenceReport(
            judgements: [judgement("a", 1, 2, .first)],
            chosen: Lookup(["a": CandidateID(1)]),
            tolerance: 0.9,
            margins: Lookup(["a": 0.4])
        )
        #expect(report.toleranceAgreement == 0)
    }

    @Test("A scene with no margin says nothing about the tolerance")
    func noMargin() {
        let report = PreferenceReport(
            judgements: [judgement("a", 1, 2, .first)],
            chosen: Lookup(["a": CandidateID(1)]),
            tolerance: 0.05
        )
        #expect(report.toleranceJudged == 0)
        #expect(!report.summary.contains("tolerance"))
    }

    @Test("The report says the numbers a reviewer needs")
    func readable() {
        let report = PreferenceReport(
            judgements: [judgement("a", 1, 2, .first), judgement("b", 3, 4, .second)],
            chosen: Lookup(["a": CandidateID(1), "b": CandidateID(3)]),
            tolerance: 0
        )
        #expect(report.summary.contains("agreement"))
        #expect(report.summary.contains("judged 2"))
    }

    @Test("The report names the scenes it disagreed about")
    func namesDisagreements() {
        let report = PreferenceReport(
            judgements: [judgement("toolbar", 1, 2, .first)],
            chosen: Lookup(["toolbar": CandidateID(2)]),
            tolerance: 0
        )
        #expect(report.disagreements == ["toolbar"])
        #expect(report.summary.contains("toolbar"))
    }

    @Test("Disagreements are named in a fixed order")
    func disagreementsAreOrdered() {
        let report = PreferenceReport(
            judgements: [
                judgement("zebra", 1, 2, .first),
                judgement("apple", 3, 4, .first),
            ],
            chosen: Lookup(["zebra": CandidateID(2), "apple": CandidateID(4)]),
            tolerance: 0
        )
        #expect(report.disagreements == ["apple", "zebra"])
    }

    @Test("Judgements survive a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable([judgement("a", 1, 2, .noDifference)]))
    }

    @Test("A judgement says which scene and which two candidates")
    func judgementIsSelfContained() throws {
        let decoded = try roundTripped(judgement("toolbar", 7, 9, .second))
        #expect(decoded.scene == "toolbar")
        #expect(decoded.first == CandidateID(7))
        #expect(decoded.second == CandidateID(9))
        #expect(decoded.verdict == .second)
    }

    @Test("Reporting is reproducible")
    func reproducible() {
        let judgements = [judgement("a", 1, 2, .first), judgement("b", 3, 4, .second)]
        let chosen = Lookup<String, CandidateID>(["a": CandidateID(1), "b": CandidateID(3)])
        #expect(
            isReproducible {
                PreferenceReport(judgements: judgements, chosen: chosen, tolerance: 0).summary
            }
        )
    }
}
