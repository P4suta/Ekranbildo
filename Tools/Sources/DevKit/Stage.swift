import Foundation


public struct Outcome: Sendable, Equatable {
    public let status: Int32
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

public struct Stage: Sendable {
    public let name: String
    public let allowsDeprecation: String?
    public let run: @Sendable (Context) throws -> Outcome

    public init(
        name: String,
        allowsDeprecation: String? = nil,
        run: @escaping @Sendable (Context) throws -> Outcome
    ) {
        self.name = name
        self.allowsDeprecation = allowsDeprecation.flatMap { $0.isEmpty ? nil : $0 }
        self.run = run
    }
}

public struct Context: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }
}

public enum Verdict: Sendable, Equatable {
    case passed
    case failed
    case deprecated
}

public struct StageResult: Sendable {
    public let stage: Stage
    public let outcome: Outcome

    public init(stage: Stage, outcome: Outcome) {
        self.stage = stage
        self.outcome = outcome
    }

    public init(attempting stage: Stage, in context: Context) {
        self.stage = stage
        do {
            outcome = try stage.run(context)
        } catch {
            outcome = Outcome(status: Self.couldNotStart, output: "\(error)")
        }
    }

    private static let couldNotStart: Int32 = -1

    public var verdict: Verdict {
        guard outcome.status == 0 else { return .failed }
        guard stage.allowsDeprecation == nil, Self.speaksOfADeadline(outcome.output) else {
            return .passed
        }
        return .deprecated
    }

    static func speaksOfADeadline(_ output: String) -> Bool {
        let lowered = output.lowercased()
        return lowered.contains(Word.adjective) || lowered.contains(Word.noun)
    }

    private enum Word {
        static let adjective = "deprecated"
        static let noun = "deprecation"
    }
}

public struct RunSummary: Sendable {
    public let results: [StageResult]

    public init(results: [StageResult]) {
        self.results = results
    }

    public var failures: [StageResult] { results.filter { $0.verdict != .passed } }

    public var succeeded: Bool { !results.isEmpty && failures.isEmpty }

    public var report: String {
        guard !results.isEmpty else { return "nothing ran, which is not the same as nothing failing" }
        guard !failures.isEmpty else { return "all \(results.count) checks passed" }
        return
            (["\(failures.count) of \(results.count) checks did not pass:"]
            + failures.map { result in
                switch result.verdict {
                case .failed: "  \(result.stage.name) exited \(result.outcome.status)"
                case .deprecated:
                    "  \(result.stage.name) says something is deprecated, and nothing "
                        + "has been written down about it"
                case .passed: ""
                }
            })
            .joined(separator: "\n")
    }
}
