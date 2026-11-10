import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoInspector
import EkranbildoLayout
import Foundation

public struct CompareOptions: Sendable, Equatable {
    public let input: String
    public let pageOutput: String?
    public let answers: String?
    public let reportOutput: String?
    public let questions: Int
    public let tolerance: Double

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "a directory of scene files is required"
            )
        }
        self.input = input
        pageOutput = parsed.value(of: "--page")
        answers = parsed.value(of: "--answers")
        reportOutput = parsed.value(of: "--report")

        if let text = parsed.value(of: "--questions") {
            guard let value = Int(text), value > 0 else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--questions needs a positive whole number, got '\(text)'"
                )
            }
            questions = value
        } else {
            questions = Defaults.questions
        }

        if let text = parsed.value(of: "--tolerance") {
            guard let value = Double(text), value >= 0, value.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--tolerance needs a number from zero up, got '\(text)'"
                )
            }
            tolerance = value
        } else {
            tolerance = Defaults.tolerance
        }
    }

    static let knownFlags = ["--page", "--answers", "--report", "--questions", "--tolerance"]

    public enum Defaults {
        public static let questions = 40
        public static let tolerance: Double = 0.05
    }
}

public struct CompareOutputs: Sendable, Equatable {
    public let page: String?
    public let report: String?
    public let agreement: Double?
    public let disagreementCount: Int
}

public struct CompareCommand: Sendable {
    private let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring = TabulatedTextMeasurer.uniform()) {
        self.measurer = measurer
    }

    public func run(scenes: [CorpusInput], options: CompareOptions) throws -> CompareOutputs {
        var pairs: [ComparisonPair] = []
        var chosen: Lookup<String, CandidateID> = Lookup()
        var margins: Lookup<String, Double> = Lookup()

        for input in scenes {
            guard
                let scene = try? JSONDecoder()
                    .decode(Scene.self, from: Data(input.json.utf8))
            else { continue }

            let unplaced = scene.annotations.filter { $0.placement == nil }
            guard !unplaced.isEmpty else { continue }

            let problem = LayoutProblem(
                canvas: scene.canvas,
                style: scene.style,
                annotations: unplaced,
                measurer: measurer
            )
            let solution = ExactSolver().solve(problem, budget: .standard)
            guard let assignment = solution.assignments.first else { continue }
            chosen[input.name] = assignment.candidateID
            if let decision = solution.trace.decisions.first {
                margins[input.name] = decision.margin
            }

            pairs.append(
                contentsOf: Self.questions(
                    for: input.name,
                    problem: problem,
                    solution: solution,
                    limit: options.questions - pairs.count
                )
            )
            if pairs.count >= options.questions { break }
        }

        let report = try options.answers.map { path -> PreferenceReport in
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let judgements = try JSONDecoder().decode([Judgement].self, from: data)
            return PreferenceReport(
                judgements: judgements,
                chosen: chosen,
                tolerance: options.tolerance,
                margins: margins
            )
        }

        return CompareOutputs(
            page: options.pageOutput == nil
                ? nil : ComparisonPage(measurer: measurer).html(for: pairs),
            report: report?.summary,
            agreement: report?.agreement,
            disagreementCount: report?.disagreements.count ?? 0
        )
    }

    static let rankStep: Double = QuerySelector.Defaults.closeEnough

    static func questions(
        for scene: String,
        problem: LayoutProblem,
        solution: LayoutSolution,
        limit: Int
    ) -> [ComparisonPair] {
        guard limit > 0 else { return [] }

        let considered = solution.trace.decisions.first?.candidates ?? []
        let scored = considered.map {
            ScoredCandidate(id: $0.id, score: Double($0.rank) * Self.rankStep)
        }
        let generated = GridCandidateGenerator().generate(forAnnotationAt: 0, in: problem)

        return QuerySelector().pairs(among: scored, asking: limit).compactMap { question in
            guard let first = generated.first(where: { $0.id == question.first }),
                let second = generated.first(where: { $0.id == question.second })
            else { return nil }
            return ComparisonPair(scene: scene, problem: problem, first: first, second: second)
        }
    }
}
