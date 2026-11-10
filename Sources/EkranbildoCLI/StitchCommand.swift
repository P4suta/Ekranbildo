import EkranbildoContracts
import EkranbildoImaging
import EkranbildoStitch
import Foundation

public struct StitchOptions: Sendable, Equatable {
    public let inputs: [String]
    public let pngOutput: String?
    public let reportOutput: String?

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        inputs = parsed.positional
        guard !inputs.isEmpty else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "at least one frame is required"
            )
        }
        pngOutput = parsed.value(of: "--png")
        reportOutput = parsed.value(of: "--report")
    }

    static let knownFlags = ["--png", "--report"]
}

public struct StitchOutputs: Sendable, Equatable {
    public let png: [UInt8]?
    public let report: String
    public let uncertainJoinCount: Int
}

public struct StitchCommand: Sendable {

    public init() {}

    public func run(frames: [[UInt8]], options: StitchOptions) throws -> StitchOutputs {
        let images = try frames.map { try ImageCodec.decode($0).image }
        let result = try Stitcher().stitch(images)

        return StitchOutputs(
            png: options.pngOutput == nil ? nil : try ImageCodec.encodePNG(result.image),
            report: Self.report(result, frameCount: images.count),
            uncertainJoinCount: result.uncertainJoins.count
        )
    }

    static func report(_ result: StitchResult, frameCount: Int) -> String {
        var lines = [
            "frames \(frameCount)",
            "page \(result.image.width)x\(result.image.height)",
            "sticky top \(result.stickyTop) bottom \(result.stickyBottom)",
            "row comparisons \(result.rowComparisons)",
        ]
        if result.uncertainJoins.isEmpty {
            lines.append("every join matched")
        } else {
            lines.append(
                contentsOf: result.uncertainJoins.map {
                    "uncertain join after frame \($0.betweenFrames) at row \($0.atRow)"
                }
            )
        }
        return lines.joined(separator: "\n")
    }
}
