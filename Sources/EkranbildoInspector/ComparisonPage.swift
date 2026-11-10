import EkranbildoContracts
import EkranbildoCore
import EkranbildoLayout
import EkranbildoRender

public struct ComparisonPair: Sendable {
    public let scene: String
    public let problem: LayoutProblem
    public let first: LayoutCandidate
    public let second: LayoutCandidate

    public init(
        scene: String,
        problem: LayoutProblem,
        first: LayoutCandidate,
        second: LayoutCandidate
    ) {
        self.scene = scene
        self.problem = problem
        self.first = first
        self.second = second
    }
}

public struct ComparisonPage: Sendable {
    private let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring) {
        self.measurer = measurer
    }

    public func html(for pairs: [ComparisonPair]) -> String {
        let questions =
            pairs.isEmpty
            ? ["<p class=\"empty\">Nothing to compare.</p>"]
            : pairs.enumerated().map { index, pair in question(pair, number: index + 1) }

        return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <title>Ekranbildo comparisons</title>
            <style>\(Self.styles)</style>
            </head>
            <body>
            <h1>Which is better?</h1>
            <p class="note">
            Answer quickly. "No difference" is a real answer and the most useful one.
            </p>
            \(questions.joined(separator: "\n"))
            </body>
            </html>
            """
    }

    private func question(_ pair: ComparisonPair, number: Int) -> String {
        """
        <section class="pair" data-scene="\(HTMLText.escaped(pair.scene))" \
        data-first="\(pair.first.id.raw)" data-second="\(pair.second.id.raw)">
        <h2>\(number)</h2>
        <div class="side-by-side">
        <figure>\(drawing(of: pair.first, in: pair.problem))<figcaption>A</figcaption></figure>
        <figure>\(drawing(of: pair.second, in: pair.problem))<figcaption>B</figcaption></figure>
        </div>
        <div class="answers">
        <button value="\(Verdict.first.rawValue)">A is better</button>
        <button value="\(Verdict.noDifference.rawValue)">No difference</button>
        <button value="\(Verdict.second.rawValue)">B is better</button>
        </div>
        </section>
        """
    }

    private func drawing(of candidate: LayoutCandidate, in problem: LayoutProblem) -> String {
        let annotation = problem.annotations[candidate.annotationIndex]
        let scene = problem.scene(
            showing: [annotation.replacing(placement: candidate.placement)])
        return SVGRenderer().render(DrawListBuilder(measurer: measurer).build(scene))
    }

    private static let styles = """
        :root { color-scheme: light dark; }
        body { font: 13px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 24px; }
        h1 { font-size: 20px; }
        h2 { font-size: 13px; color: #888; font-weight: 400; }
        .note { color: #666; }
        .pair { border-top: 1px solid #8883; padding-top: 12px; margin-top: 20px; }
        .side-by-side { display: flex; gap: 16px; flex-wrap: wrap; }
        figure { margin: 0; }
        figcaption { font-size: 11px; color: #666; text-align: center; }
        svg { max-width: 420px; height: auto; border: 1px solid #8884; }
        .answers { display: flex; gap: 8px; margin-top: 10px; }
        button { font: inherit; padding: 6px 14px; }
        .empty { color: #666; }
        """
}

public struct ScoredCandidate: Hashable, Sendable {
    public let id: CandidateID
    public let score: Double

    public init(id: CandidateID, score: Double) {
        self.id = id
        self.score = score
    }
}

public struct QuerySelector: Sendable {
    private let closeEnough: Double

    public init(closeEnough: Double = Defaults.closeEnough) {
        self.closeEnough = closeEnough
    }

    public enum Defaults {
        public static let closeEnough: Double = 0.05
    }

    public struct Question: Hashable, Sendable {
        public let first: CandidateID
        public let second: CandidateID
    }

    public func pairs(among candidates: [ScoredCandidate], asking count: Int) -> [Question] {
        guard candidates.count > 1, count > 0 else { return [] }

        let ordered = candidates.sorted {
            $0.score == $1.score ? $0.id.raw < $1.id.raw : $0.score < $1.score
        }

        var chosen: [Question] = []
        for index in 0..<(ordered.count - 1) {
            let gap = ordered[index + 1].score - ordered[index].score
            guard gap <= closeEnough else { continue }
            chosen.append(Question(first: ordered[index].id, second: ordered[index + 1].id))
            if chosen.count == count { break }
        }
        return chosen
    }
}
