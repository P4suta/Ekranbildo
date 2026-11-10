import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoInspector
import Foundation

public struct CorpusInput: Sendable {
    public let name: String
    public let json: String

    public init(name: String, json: String) {
        self.name = name
        self.json = json
    }
}

public struct CorpusOptions: Sendable, Equatable {
    public let input: String
    public let sheetOutput: String?
    public let scoreboardOutput: String?

    static let knownFlags = ["--sheet", "--scoreboard"]

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "a directory of scene files is required"
            )
        }
        self.input = input
        sheetOutput = parsed.value(of: "--sheet")
        scoreboardOutput = parsed.value(of: "--scoreboard")
    }
}

public struct CorpusOutputs: Sendable {
    public let sheet: String
    public let scoreboard: String
    public let failureCount: Int
}

public struct CorpusCommand: Sendable {
    private let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring = TabulatedTextMeasurer.uniform()) {
        self.measurer = measurer
    }

    public func run(scenes: [CorpusInput]) -> CorpusOutputs {
        let report = CorpusRunner(measurer: measurer)
            .run(scenes.map { CorpusScene(name: $0.name, json: $0.json) })
        return CorpusOutputs(
            sheet: report.html,
            scoreboard: report.scoreboard,
            failureCount: report.failureCount
        )
    }
}

public enum Command: Sendable {
    case render(RenderOptions)
    case corpus(CorpusOptions)
    case detect(DetectOptions)
    case capture(CaptureOptions)
    case annotate(AnnotateOptions)
    case stitch(StitchOptions)
    case record(RecordOptions)
    case redact(RedactOptions)
    case compare(CompareOptions)
    case camera(CameraOptions)
    case renderVideo(RenderVideoOptions)
    case synthesise(SynthesiseOptions)
    case replay(ReplayOptions)
    case bisect(BisectOptions)
    case icon(IconOptions)

    public init(arguments: [String]) throws {
        let rest = Array(arguments.dropFirst())
        guard let name = arguments.first, let build = Self.builders[name] else {
            self = .render(try RenderOptions(arguments: arguments))
            return
        }
        self = try build(rest)
    }

    private static let builders: [String: @Sendable ([String]) throws -> Self] = [
        "corpus": { .corpus(try CorpusOptions(arguments: $0)) },
        "detect": { .detect(try DetectOptions(arguments: $0)) },
        "capture": { .capture(try CaptureOptions(arguments: $0)) },
        "annotate": { .annotate(try AnnotateOptions(arguments: $0)) },
        "stitch": { .stitch(try StitchOptions(arguments: $0)) },
        "record": { .record(try RecordOptions(arguments: $0)) },
        "redact": { .redact(try RedactOptions(arguments: $0)) },
        "compare": { .compare(try CompareOptions(arguments: $0)) },
        "camera": { .camera(try CameraOptions(arguments: $0)) },
        "render-video": { .renderVideo(try RenderVideoOptions(arguments: $0)) },
        "synthesise": { .synthesise(try SynthesiseOptions(arguments: $0)) },
        "replay": { .replay(try ReplayOptions(arguments: $0)) },
        "bisect": { .bisect(try BisectOptions(arguments: $0)) },
        "icon": { .icon(try IconOptions(arguments: $0)) },
    ]
}
