import Foundation


public struct Checks: Sendable {
    public let root: URL
    public let brief: Bool

    public init(root: URL, brief: Bool) {
        self.root = root
        self.brief = brief
    }

    public var required: [String] {
        ["swift", "xcrun", "mise", "nm", "xmllint", "ocomment"]
    }

    public func fixes() throws -> [Stage] {
        let xcrun = try Toolchain.locate("xcrun").path()
        let mise = try Toolchain.locate("mise").path()
        let directories = ["Sources", "Tests", "Package.swift"]

        func format() -> Stage {
            Stage(name: "Format") { context in
                try Command.run(
                    xcrun, ["swift-format", "format", "--recursive", "-i"] + directories,
                    in: context.root)
            }
        }
        return [
            format(),
            Stage(name: "SwiftLint fixes") { context in
                try Command.run(
                    mise, ["exec", "--", "swiftlint", "--fix", "--quiet"], in: context.root)
            },
            Stage(name: "Comments") { context in
                let ocomment = try Toolchain.locate("ocomment").path()
                return try Command.run(
                    ocomment, ["fix", "--no-preview"] + Self.commented, in: context.root)
            },
            format(),
            Stage(name: "Build") { context in
                try Command.run(
                    try Toolchain.locate("swift").path(),
                    ["build", "--build-tests"],
                    in: context.root
                )
            },
        ]
    }

    public func stages() throws -> [Stage] {
        let swift = try Toolchain.locate("swift").path()
        let xcrun = try Toolchain.locate("xcrun").path()
        let mise = try Toolchain.locate("mise").path()

        func tool(_ path: String, _ arguments: [String]) -> @Sendable (Context) throws -> Outcome {
            { context in try Command.run(path, arguments, in: context.root) }
        }
        func script(_ name: String, _ arguments: [String] = []) -> @Sendable (Context) throws -> Outcome {
            { context in
                try Command.run(
                    context.root.appendingPathComponent("Scripts/\(name)").path,
                    arguments,
                    in: context.root
                )
            }
        }

        var stages: [Stage] = [
            Stage(name: "Build", run: tool(swift, ["build", "--build-tests"])),
            Stage(name: "Tests", run: tool(swift, ["test"])),
            Stage(name: "Tests (release)", run: tool(swift, ["test", "-c", "release"])),
            Stage(
                name: "Format",
                run: tool(
                    xcrun,
                    [
                        "swift-format", "lint", "--recursive", "--strict",
                        "Sources", "Tests", "Package.swift",
                    ])
            ),
            Stage(name: "SwiftLint", run: tool(mise, ["exec", "--", "swiftlint", "lint", "--quiet"])),
            Stage(name: "Comments", run: comments),
            Stage(name: "Rebuilds", run: rebuilds),
            Stage(name: "Numbers", run: numbers),
            Stage(name: "Choices", run: choices),
            Stage(name: "Outcomes", run: outcomes),
            Stage(name: "Relations", run: relations),
            Stage(name: "Licence", run: licence),
            Stage(name: "Typos", run: tool(mise, ["exec", "--", "typos"])),
            Stage(name: "Dependencies", run: dependencies),
            Stage(name: "Artifact", run: artifact),
            Stage(name: "Instrument", run: script("build-instrument.sh")),
            Stage(
                name: "Secret scan",
                run: tool(
                    mise,
                    [
                        "exec", "--", "gitleaks", "dir", ".", "--no-banner", "--redact",
                        "--config", ".gitleaks.toml",
                    ])
            ),
            Stage(name: "Determinism", run: determinism),
            Stage(name: "Negative compile", run: negativeCompile),
        ]

        if !brief {
            stages.append(
                Stage(
                    name: "Dead code",
                    allowsDeprecation:
                        "Periphery needs an index store and only the old build system writes one",
                    run: tool(
                        mise,
                        [
                            "exec", "--", "periphery", "scan", "--quiet", "--strict",
                            "--", "--build-system", "native",
                        ])
                )
            )
        }

        return stages
    }

    private var determinism: @Sendable (Context) throws -> Outcome {
        { context in
            let found = try DeterminismRules.scan(
                Self.coreModules.map {
                    context.root.appendingPathComponent("Sources/\($0)")
                })
            let lines = found.flatMap { ["  \($0.path):\($0.line)", "      \($0.advice)"] }
            return Outcome(
                status: found.isEmpty ? 0 : 1,
                output: lines.joined(separator: "\n")
            )
        }
    }

    private var negativeCompile: @Sendable (Context) throws -> Outcome {
        { context in
            let swift = try Toolchain.locate("swift").path()
            let built = try Command.run(swift, ["build"], in: context.root)
            guard built.status == 0 else {
                throw Command.Failure(description: "the package does not build")
            }
            let shown = try Command.run(swift, ["build", "--show-bin-path"], in: context.root)
            let modules = URL(
                fileURLWithPath: shown.output.trimmingCharacters(in: .whitespacesAndNewlines))

            var lines: [String] = []
            var wrong = 0
            for snippet in Snippets.all {
                let compiled = try Snippets.compiles(snippet, against: modules, in: context.root)
                lines.append(snippet.report(compiled: compiled))
                if snippet.verdict(compiled: compiled) == .unexpected {
                    wrong += 1
                    if snippet.expectation == .compiles { break }
                }
            }
            return Outcome(status: wrong == 0 ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var rebuilds: @Sendable (Context) throws -> Outcome {
        { context in
            let files = try Self.swiftFiles(under: ["Sources"], at: context.root)
            let sources = try files.map { try String(contentsOf: $0, encoding: .utf8) }

            var protected: Set<String> = []
            for source in sources {
                protected.formUnion(RebuildRules.protectedTypes(in: source))
            }

            var found: [Finding] = []
            for (file, source) in zip(files, sources) {
                found += RebuildRules.findings(
                    in: source,
                    path: Self.relative(file, to: context.root),
                    protecting: protected
                )
            }
            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var choices: @Sendable (Context) throws -> Outcome {
        { context in
            let files = try Self.swiftFiles(under: ["Sources", "Tools/Sources"], at: context.root)
            let sources = try files.map { try String(contentsOf: $0, encoding: .utf8) }

            var ours: Set<String> = []
            for source in sources {
                ours.formUnion(ChoiceRules.casesWeDeclare(in: source))
            }

            var found: [Finding] = []
            for (file, source) in zip(files, sources) {
                found += ChoiceRules.findings(
                    in: source,
                    path: Self.relative(file, to: context.root),
                    ours: ours
                )
            }
            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var outcomes: @Sendable (Context) throws -> Outcome {
        { context in
            let files = try Self.swiftFiles(under: ["Sources", "Tools/Sources"], at: context.root)
            var found: [Finding] = []
            for file in files {
                found += OutcomeRules.findings(
                    in: try String(contentsOf: file, encoding: .utf8),
                    path: Self.relative(file, to: context.root)
                )
            }
            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var relations: @Sendable (Context) throws -> Outcome {
        { context in
            let files = try Self.swiftFiles(under: ["Sources", "Tools/Sources"], at: context.root)
            var found: [Finding] = []
            for file in files {
                found += RelationRules.findings(
                    in: try String(contentsOf: file, encoding: .utf8),
                    path: Self.relative(file, to: context.root)
                )
            }
            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var licence: @Sendable (Context) throws -> Outcome {
        { context in
            let found = try LicenceRules.check(in: context.root)
            let lines = found.map { "  \($0.path)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    static func swiftFiles(under directories: [String], at root: URL) throws -> [URL] {
        var found: [URL] = []
        for directory in directories {
            let base = root.appendingPathComponent(directory)
            guard
                let walker = FileManager.default.enumerator(
                    at: base, includingPropertiesForKeys: nil)
            else { continue }
            for case let file as URL in walker where file.pathExtension == "swift" {
                found.append(file)
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    static func relative(_ file: URL, to root: URL) -> String {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return file.path.hasPrefix(prefix)
            ? String(file.path.dropFirst(prefix.count)) : file.path
    }

    private var numbers: @Sendable (Context) throws -> Outcome {
        { context in
            var found: [Finding] = []
            for file in try Self.swiftFiles(under: ["Sources"], at: context.root) {
                let source = try String(contentsOf: file, encoding: .utf8)
                found += LiteralRules.findings(
                    in: source, path: Self.relative(file, to: context.root))
            }
            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var comments: @Sendable (Context) throws -> Outcome {
        { context in
            let ocomment = try Toolchain.locate("ocomment").path()
            return try Command.run(
                ocomment,
                ["check", "--no-preview"] + Self.commented,
                in: context.root
            )
        }
    }

    static let commented = ["Sources", "Tests", "Tools/Sources", "Tools/Tests", "Package.swift"]

    private var artifact: @Sendable (Context) throws -> Outcome {
        { context in
            var found: [Finding] = []
            var lines: [String] = []
            for product in ArtifactRules.products(of: ArtifactRules.forbidden) {
                let names = ArtifactRules.names(in: product, among: ArtifactRules.forbidden)
                let debug = try ArtifactRules.symbols(
                    of: "debug", product: product, at: context.root)
                let release = try ArtifactRules.symbols(
                    of: "release", product: product, at: context.root)
                let wrong = ArtifactRules.check(debug: debug, release: release, names: names)
                found += wrong
                lines +=
                    wrong.isEmpty
                    ? names.map { "  \(product): absent from release, present in debug: \($0.symbol)" }
                    : wrong.map { "  \(product): \($0.advice)" }
            }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    private var dependencies: @Sendable (Context) throws -> Outcome {
        { context in
            let manifest = try Manifest.read(at: context.root)
            var found: [Finding] = []

            for root in ["Sources", "Tests"] {
                let directory = context.root.appendingPathComponent(root)
                let contents =
                    (try? FileManager.default.contentsOfDirectory(
                        at: directory, includingPropertiesForKeys: nil)) ?? []
                for module in contents.sorted(by: { $0.path < $1.path }) {
                    let name = module.lastPathComponent
                    for file in try DeterminismRules.swiftFiles(in: module) {
                        let source = try String(contentsOf: file, encoding: .utf8)
                        let imports = ImportRules.imports(in: source)
                        let path = file.path.replacingOccurrences(
                            of: context.root.path + "/", with: "")
                        found += ImportRules.forbidden(imports: imports, in: name)
                            .map { Finding(path: path, line: $0.line, advice: $0.advice) }
                        found += manifest.undeclared(imports: imports, by: name, in: path)
                    }
                }
            }

            let lines = found.map { "  \($0.path):\($0.line)\n      \($0.advice)" }
            return Outcome(status: found.isEmpty ? 0 : 1, output: lines.joined(separator: "\n"))
        }
    }

    public static let coreModules = [
        "EkranbildoGeometry", "EkranbildoContracts", "EkranbildoCore", "EkranbildoField",
        "EkranbildoLayout", "EkranbildoRender", "EkranbildoTimeline",
    ]
}
