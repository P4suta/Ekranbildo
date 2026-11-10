import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoLayout
import EkranbildoRender
import Foundation

public struct ReplayOptions: Sendable, Equatable {
    public let input: String
    public let rerecord: Bool
    public let answerOutput: String?

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput, detail: "a replay bundle is required")
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }

        self.input = input
        rerecord = parsed.value(of: "--record") == Words.yes
        answerOutput = parsed.value(of: "--answer")
    }

    static let knownFlags = ["--answer", "--record"]

    private enum Words {
        static let yes = "yes"
    }
}

public struct ReplayOutputs: Sendable {
    public let verdict: ReplayVerdict
    public let answerText: String
    public let rerecorded: String?
}

public struct ReplayCommand: Sendable {
    private let solver: SceneSolver

    public init(measurer: any TextMeasuring = TabulatedTextMeasurer.uniform()) {
        solver = SceneSolver(measurer: measurer)
    }

    public static let pipeline = LayoutVersion.current.with(
        renderer: RenderVersion.current,
        visionRevision: PipelineVersion.unnamed
    )

    public func record(sceneJSON: String) throws -> String {
        let scene = try Self.decode(sceneJSON)
        let solved = solver.solve(scene)
        let bundle = ReplayBundle(
            scene: scene,
            pipeline: Self.pipeline,
            answer: ReplayBundle.answer(for: solved.scene, reasons: solved.reasons)
        )
        do {
            return try ReplayBundle.encode(bundle)
        } catch {
            throw CommandError(
                code: CommandError.undecodableScene,
                detail: "could not write the bundle: \(error)"
            )
        }
    }

    public func run(bundleJSON: String, rerecord: Bool = false) throws -> ReplayOutputs {
        let bundle: ReplayBundle
        do {
            bundle = try ReplayBundle.decode(bundleJSON)
        } catch let error as ReplayBundleError {
            throw CommandError(code: CommandError.undecodableScene, detail: error.detail)
        }

        let solved = solver.solve(bundle.scene)
        let answer = ReplayBundle.answer(for: solved.scene, reasons: solved.reasons)
        let verdict = bundle.compare(answer, from: Self.pipeline)

        var rerecorded: String?
        if rerecord {
            rerecorded = try? ReplayBundle.encode(
                ReplayBundle(scene: bundle.scene, pipeline: Self.pipeline, answer: answer)
            )
        }

        return ReplayOutputs(
            verdict: verdict,
            answerText: Self.text(of: answer),
            rerecorded: rerecorded
        )
    }

    static func text(of answer: [RecordedPlacement]) -> String {
        answer
            .sorted { $0.annotation.raw < $1.annotation.raw }
            .map { "annotation \($0.annotation.raw) \($0.summary)" }
            .joined(separator: "\n")
    }

    private static func decode(_ sceneJSON: String) throws -> Scene {
        do {
            return try JSONDecoder().decode(Scene.self, from: Data(sceneJSON.utf8))
        } catch {
            throw CommandError(
                code: CommandError.undecodableScene,
                detail: "could not decode the scene: \(error)"
            )
        }
    }
}
