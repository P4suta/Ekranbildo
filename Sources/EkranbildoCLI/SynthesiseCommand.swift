import EkranbildoContracts
import EkranbildoCore
import EkranbildoObservability
import Foundation

public struct SynthesiseOptions: Sendable, Equatable {
    public let input: String
    public let output: String?
    public let reportOutput: String?
    public let traceInput: String?
    public let traceOutput: String?

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "a scene is required"
            )
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }
        self.input = input
        output = parsed.value(of: "--out")
        reportOutput = parsed.value(of: "--report")
        traceInput = parsed.value(of: "--trace")
        traceOutput = parsed.value(of: "--trace-out")

        if traceInput != nil && traceOutput == nil {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "--trace needs --trace-out: the safe trace is not written over the original"
            )
        }
    }

    static let knownFlags = ["--out", "--report", "--trace", "--trace-out"]
}

public struct SynthesiseOutputs: Sendable, Equatable {
    public let scene: String
    public let report: String
    public let replacedLabels: Int
    public let replacedPictures: Int
}

public struct SynthesiseCommand: Sendable {
    private let synthesis: Synthesis

    public init(synthesis: Synthesis = Synthesis()) {
        self.synthesis = synthesis
    }

    public func synthesised(trace: String) -> String {
        TraceSynthesis.applied(to: trace)
    }

    public func run(sceneJSON: String) throws -> SynthesiseOutputs {
        let scene: Scene
        do {
            scene = try JSONDecoder().decode(Scene.self, from: Data(sceneJSON.utf8))
        } catch {
            throw CommandError(
                code: CommandError.undecodableScene,
                detail: "could not read the scene: \(error)"
            )
        }

        let safe = synthesis.synthesised(scene)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(safe)

        var lines: [String] = []
        for (was, now) in zip(scene.annotations, safe.annotations) {
            lines.append("label \(was.id.raw) \(was.label.count) characters -> \(now.label)")
        }
        if let was = scene.background, let now = safe.background {
            lines.append(
                "picture \(was.pixelWidth)x\(was.pixelHeight) -> \(now.contentHash)")
        }

        return SynthesiseOutputs(
            scene: String(bytes: encoded, encoding: .utf8) ?? "",
            report: lines.joined(separator: "\n"),
            replacedLabels: scene.annotations.count,
            replacedPictures: scene.background == nil ? 0 : 1
        )
    }
}
