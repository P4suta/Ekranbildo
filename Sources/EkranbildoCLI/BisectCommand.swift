import EkranbildoCore

public struct BisectOptions: Sendable, Equatable {
    public let input: String
    public let versions: [String]
    public let run: String

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput, detail: "a replay bundle is required")
        }
        guard let listed = parsed.value(of: "--versions") else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "--versions is required, oldest first, separated by commas"
            )
        }
        guard let run = parsed.value(of: "--run") else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "--run is required: the command that asks one build for its answer"
            )
        }

        let versions = listed.components(separatedBy: Format.separator)
        guard !versions.contains(where: \.isEmpty) else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--versions has an empty entry: '\(listed)'"
            )
        }
        guard versions.count >= Format.endsOfARange else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--versions needs at least two versions to search between"
            )
        }
        guard run.contains(Placeholder.version) else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--run has no \(Placeholder.version) in it, so every build "
                    + "would be asked the same question"
            )
        }

        self.input = input
        self.versions = versions
        self.run = run
    }

    static let knownFlags = ["--versions", "--run"]

    private enum Format {
        static let separator = ","
        static let endsOfARange = 2
    }
}

public struct BisectCommand: Sendable {
    public init() {}

    public func run(
        bundleJSON: String,
        options: BisectOptions,
        ask: (String) throws -> String
    ) throws -> Bisection.Search {
        let bundle: ReplayBundle
        do {
            bundle = try ReplayBundle.decode(bundleJSON)
        } catch let error as ReplayBundleError {
            throw CommandError(code: CommandError.undecodableScene, detail: error.detail)
        }

        let recorded = ReplayCommand.text(of: bundle.answer)
        return try Bisection.firstDiffering(over: options.versions, matching: recorded) { version in
            try ask(version)
        }
    }

    public static func commandLine(_ template: String, version: String, bundle: String) -> String {
        template
            .replacingOccurrences(of: Placeholder.version, with: version)
            .replacingOccurrences(of: Placeholder.bundle, with: bundle)
    }
}

private enum Placeholder {
    static let version = "{version}"
    static let bundle = "{bundle}"
}
