import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoInspector
import EkranbildoLayout
import EkranbildoTestKit
import Testing

@Suite("Comparison page")
struct ComparisonPageTests {

    private let measurer = TabulatedTextMeasurer.uniform()

    private func problem() -> LayoutProblem {
        LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 300, height: 200),
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 130, y: 90, width: 40, height: 20),
                    label: "Here",
                    placement: nil
                )
            ],
            measurer: measurer
        )
    }

    private func pair() -> ComparisonPair {
        let candidates = GridCandidateGenerator().generate(forAnnotationAt: 0, in: problem())
        return ComparisonPair(
            scene: "sample",
            problem: problem(),
            first: candidates[0],
            second: candidates[candidates.count / 2]
        )
    }

    @Test("The page shows both placements")
    func showsBoth() {
        let html = ComparisonPage(measurer: measurer).html(for: [pair()])
        #expect(html.components(separatedBy: "<svg").count - 1 >= 2)
    }

    @Test("Neither placement is described to the person answering")
    func unlabelled() {
        let html = ComparisonPage(measurer: measurer).html(for: [pair()])
        #expect(html.contains("<figcaption>A</figcaption>"))
        #expect(html.contains("<figcaption>B</figcaption>"))

        for giveaway in ["chosen", "winner", "score", "preferred", "recommended"] {
            #expect(!html.lowercased().contains(giveaway), "the page says '\(giveaway)'")
        }
    }

    @Test("Every question offers all three answers")
    func threeAnswers() {
        let html = ComparisonPage(measurer: measurer).html(for: [pair()])
        for verdict in [Verdict.first, .second, .noDifference] {
            #expect(html.contains(verdict.rawValue), "\(verdict) cannot be given")
        }
    }

    @Test("Each question carries what an answer needs to mean anything")
    func carriesIdentity() {
        let pair = pair()
        let html = ComparisonPage(measurer: measurer).html(for: [pair])
        #expect(html.contains(pair.scene))
        #expect(html.contains("\(pair.first.id.raw)"))
        #expect(html.contains("\(pair.second.id.raw)"))
    }

    @Test("A page with nothing to ask says so rather than being blank")
    func nothingToAsk() {
        let html = ComparisonPage(measurer: measurer).html(for: [])
        #expect(html.contains("Nothing"))
    }

    @Test("A label that looks like markup is not markup")
    func escapes() {
        let hostile = LayoutProblem(
            canvas: SceneRect(x: 0, y: 0, width: 300, height: 200),
            style: .standard,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 130, y: 90, width: 40, height: 20),
                    label: "<script>alert(1)</script>",
                    placement: nil
                )
            ],
            measurer: measurer
        )
        let candidates = GridCandidateGenerator().generate(forAnnotationAt: 0, in: hostile)
        let html = ComparisonPage(measurer: measurer).html(
            for: [
                ComparisonPair(
                    scene: "hostile",
                    problem: hostile,
                    first: candidates[0],
                    second: candidates[1]
                )
            ]
        )
        #expect(!html.contains("<script"))
    }

    @Test("The page is the same every time it is built")
    func reproducible() {
        let pairs = [pair()]
        #expect(isReproducible { ComparisonPage(measurer: measurer).html(for: pairs) })
    }
}

@Suite("Choosing what to ask")
struct QuerySelectionTests {

    private func candidate(_ id: UInt32, score: Double) -> ScoredCandidate {
        ScoredCandidate(id: CandidateID(id), score: score)
    }

    @Test("The closest decisions are asked about first")
    func closestFirst() {
        let pairs = QuerySelector().pairs(
            among: [
                candidate(1, score: 0.10),
                candidate(2, score: 0.11),
                candidate(3, score: 0.90),
            ],
            asking: 1
        )
        #expect(pairs == [QuerySelector.Question(first: CandidateID(1), second: CandidateID(2))])
    }

    @Test("A decision made by a wide margin is not asked about")
    func skipsCertainDecisions() {
        let pairs = QuerySelector(closeEnough: 0.05).pairs(
            among: [candidate(1, score: 0.1), candidate(2, score: 0.9)],
            asking: 5
        )
        #expect(pairs.isEmpty)
    }

    @Test("Only as many questions as were asked for")
    func limitsQuestions() {
        let candidates = (1...10).map { candidate(UInt32($0), score: Double($0) / 1000) }
        #expect(QuerySelector().pairs(among: candidates, asking: 3).count == 3)
    }

    @Test("Nothing to compare is no questions rather than a failure")
    func nothingToCompare() {
        #expect(QuerySelector().pairs(among: [], asking: 5).isEmpty)
        #expect(QuerySelector().pairs(among: [candidate(1, score: 0.5)], asking: 5).isEmpty)
    }

    @Test("Choosing is reproducible")
    func reproducible() {
        let candidates = (1...8).map { candidate(UInt32($0), score: Double($0) / 100) }
        #expect(isReproducible { QuerySelector().pairs(among: candidates, asking: 4) })
    }

    @Test("Candidates that score the same are ordered by which they are")
    func tiesAreBrokenByIdentity() {
        let tied = [
            ScoredCandidate(id: CandidateID(7), score: 0.4),
            ScoredCandidate(id: CandidateID(2), score: 0.4),
            ScoredCandidate(id: CandidateID(5), score: 0.4),
        ]
        let asked = QuerySelector().pairs(among: tied, asking: 2)
        #expect(
            asked == [
                QuerySelector.Question(first: CandidateID(2), second: CandidateID(5)),
                QuerySelector.Question(first: CandidateID(5), second: CandidateID(7)),
            ])
    }

    @Test("The order they arrive in makes no difference")
    func orderOfArrivalDoesNotMatter() {
        let scores: [(UInt32, Double)] = [(7, 0.4), (2, 0.4), (5, 0.4), (9, 0.41)]
        let forwards = scores.map { ScoredCandidate(id: CandidateID($0.0), score: $0.1) }
        let backwards = Array(forwards.reversed())

        #expect(
            QuerySelector().pairs(among: forwards, asking: 4)
                == QuerySelector().pairs(among: backwards, asking: 4))
    }
}
