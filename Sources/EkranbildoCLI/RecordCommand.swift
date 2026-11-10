import EkranbildoContracts
import EkranbildoImaging
import EkranbildoObservability
import Foundation

public struct RecordOptions: Sendable, Equatable {
    public let seconds: Double
    public let displayID: UInt32?
    public let summaryOutput: String?
    public let framesDirectory: String?
    public let scale: Double

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard parsed.positional.isEmpty else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[0])'"
            )
        }

        if let text = parsed.value(of: "--seconds") {
            guard let value = Double(text), value > 0, value.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--seconds needs a positive number, got '\(text)'"
                )
            }
            seconds = value
        } else {
            seconds = Defaults.seconds
        }

        if let text = parsed.value(of: "--display") {
            guard let value = UInt32(text) else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--display needs an identifier, got '\(text)'"
                )
            }
            displayID = value
        } else {
            displayID = nil
        }

        summaryOutput = parsed.value(of: "--summary")
        framesDirectory = parsed.value(of: "--frames")

        if let text = parsed.value(of: "--scale") {
            guard let value = Double(text), value > 0, value.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--scale needs a positive number, got '\(text)'"
                )
            }
            scale = value
        } else {
            scale = Defaults.scale
        }
    }

    static let knownFlags = ["--seconds", "--display", "--summary", "--frames", "--scale"]

    public enum Defaults {
        public static let seconds: Double = 3
        public static let scale: Double = 1
    }
}

public struct RecordOutputs: Sendable, Equatable {
    public let summary: String
    public let frames: [NamedPicture]
    public let timings: String
    public let cursor: String
}

public struct RecordCommand: Sendable {

    public init() {}

    public func describe(
        _ recording: Recording,
        assets: InMemoryAssetStore,
        options: RecordOptions
    ) throws -> RecordOutputs {
        var frames: [NamedPicture] = []
        if options.framesDirectory != nil {
            for (index, frame) in recording.frames.enumerated() {
                guard let image = assets.image(for: frame.image) else { continue }
                frames.append(
                    NamedPicture(
                        name: Self.frameName(index),
                        png: try ImageCodec.encodePNG(image)
                    ))
            }
        }
        return RecordOutputs(
            summary: Self.summary(recording, assets: assets),
            frames: frames,
            timings: Self.timings(recording),
            cursor: try Self.cursor(recording)
        )
    }

    static func timings(_ recording: Recording) -> String {
        recording.frames.enumerated()
            .map { index, frame in
                "\(frameName(index)) "
                    + CanonicalText.rounded(frame.presentedAt.seconds, places: Precision.places)
            }
            .joined(separator: "\n")
    }

    static func cursor(_ recording: Recording) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(
            RecordedCursor(geometry: recording.geometry, samples: recording.cursor))
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    public static func frameName(_ index: Int) -> String {
        let digits = String(index)
        let padding = String(
            repeating: "0", count: max(0, Naming.digits - digits.count))
        return "frame-\(padding)\(digits).png"
    }

    static func summary(_ recording: Recording, assets: InMemoryAssetStore) -> String {
        var lines = [
            "frames \(recording.frames.count)",
            "distinct pictures \(assets.count)",
            "duration \(CanonicalText.rounded(recording.duration.seconds, places: Precision.places))s",
            "dropped \(recording.droppedFrameCount)",
            "size \(recording.geometry.pixelWidth)x\(recording.geometry.pixelHeight)px",
            "cursor samples \(recording.cursor.count)",
        ]
        lines.append(
            contentsOf: recording.events.map {
                "event \(CanonicalText.rounded($0.at.seconds, places: Precision.places))s \($0.kind.rawValue)"
            }
        )
        return lines.joined(separator: "\n")
    }

    private enum Naming {
        static let digits = 6
    }

    private enum Precision {
        static let places = 3
    }
}
