import EkranbildoContracts
import EkranbildoInspector
import EkranbildoTimeline
import Foundation

public struct CameraOptions: Sendable, Equatable {
    public let input: String
    public let keyframesOutput: String?
    public let reportOutput: String?

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "a file of camera events is required"
            )
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }
        self.input = input
        keyframesOutput = parsed.value(of: "--keyframes")
        reportOutput = parsed.value(of: "--report")
    }

    static let knownFlags = ["--keyframes", "--report"]
}

public struct CameraInput: Sendable, Codable {
    public let frame: SceneRect
    public let duration: Timestamp
    public let events: [CameraEvent]
    public let overrides: [CameraOverride]

    public init(
        frame: SceneRect,
        duration: Timestamp,
        events: [CameraEvent],
        overrides: [CameraOverride] = []
    ) {
        self.frame = frame
        self.duration = duration
        self.events = events
        self.overrides = overrides
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        frame = try container.decode(SceneRect.self, forKey: .frame)
        duration = try container.decode(Timestamp.self, forKey: .duration)
        events = try container.decodeIfPresent([CameraEvent].self, forKey: .events) ?? []
        overrides =
            try container.decodeIfPresent([CameraOverride].self, forKey: .overrides) ?? []
    }
}

public struct CameraOutputs: Sendable, Equatable {
    public let keyframes: String
    public let report: String?
    public let keyframeCount: Int
}

public struct CameraCommand: Sendable {

    public init() {}

    public func run(inputJSON: String, options: CameraOptions) throws -> CameraOutputs {
        let input: CameraInput
        do {
            input = try JSONDecoder().decode(CameraInput.self, from: Data(inputJSON.utf8))
        } catch {
            throw CommandError(
                code: CommandError.undecodableScene,
                detail: "could not read the camera events: \(error)"
            )
        }

        let path = CameraPathSolver().solve(
            events: input.events,
            frame: input.frame,
            duration: input.duration,
            overrides: input.overrides
        )
        let report = CameraReport()

        return CameraOutputs(
            keyframes: report.canonicalText(of: path),
            report: options.reportOutput == nil
                ? nil : report.html(of: path, frame: input.frame),
            keyframeCount: path.keyframes.count
        )
    }
}
