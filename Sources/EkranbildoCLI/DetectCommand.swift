import EkranbildoContracts
import EkranbildoImaging
import EkranbildoInspector
import EkranbildoSemantics
import Foundation

public struct DetectOptions: Sendable, Equatable {
    public let input: String
    public let elementsOutput: String?
    public let reportOutput: String?
    public let snapPoint: ScenePoint?
    public let snapshotOutput: String?
    public let detector: Detector

    public enum Detector: String, Sendable, CaseIterable {
        case regions
        case vision
        case all
    }

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(code: CommandError.missingInput, detail: "an image file is required")
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }

        self.input = input
        elementsOutput = parsed.value(of: "--elements")
        reportOutput = parsed.value(of: "--report")
        snapshotOutput = parsed.value(of: "--snapshot")

        if let name = parsed.value(of: "--detector") {
            guard let chosen = Detector(rawValue: name) else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: """
                        --detector must be one of \
                        \(Detector.allCases.map(\.rawValue).joined(separator: ", ")), \
                        got '\(name)'
                        """
                )
            }
            detector = chosen
        } else {
            detector = .regions
        }

        if let text = parsed.value(of: "--snap") {
            snapPoint = try Self.point(from: text)
        } else {
            snapPoint = nil
        }
    }

    static let knownFlags = ["--elements", "--report", "--snap", "--snapshot", "--detector"]

    private static func point(from text: String) throws -> ScenePoint {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == Coordinates.count,
            let x = Double(parts[0]), let y = Double(parts[1]),
            x.isFinite, y.isFinite
        else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--snap needs a point as x,y, got '\(text)'"
            )
        }
        return ScenePoint(x: x, y: y)
    }

    private enum Coordinates {
        static let count = 2
    }
}

public struct DetectOutputs: Sendable, Equatable {
    public let elements: String?
    public let report: String?
    public let snapshot: String?
    public let ladder: [SceneRect]
}

public struct DetectCommand: Sendable {
    private let providers: [DetectOptions.Detector: any SemanticProvider]

    public init(providers: [DetectOptions.Detector: any SemanticProvider] = [:]) {
        var resolved = providers
        resolved[.regions] = resolved[.regions] ?? RegionSemanticProvider()
        self.providers = resolved
    }

    public func run(imageBytes: [UInt8], options: DetectOptions) throws -> DetectOutputs {
        let decoded = try ImageCodec.decode(imageBytes)
        let image = decoded.image
        guard let provider = providers[options.detector] else {
            throw CommandError(
                code: CommandError.unavailableDetector,
                detail: "the '\(options.detector.rawValue)' detector is not available here"
            )
        }

        let semantics = try provider.analyse(image)
        let ladder = options.snapPoint.map {
            TargetSnapper().targets(among: semantics.elements, at: $0)
        }

        return DetectOutputs(
            elements: options.elementsOutput == nil
                ? nil : ScreenElement.listing(semantics.elements),
            report: options.reportOutput == nil
                ? nil
                : DetectionReport().html(
                    elements: semantics.elements,
                    image: imageBytes,
                    width: image.width,
                    height: image.height,
                    ladder: ladder ?? []
                ),
            snapshot: options.snapshotOutput == nil ? nil : try Self.snapshotText(semantics),
            ladder: ladder ?? []
        )
    }

    static func snapshotText(_ semantics: SceneSemantics) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let written = try encoder.encode(semantics)
        guard let text = String(data: written, encoding: .utf8) else {
            throw CommandError(
                code: CommandError.unwritableText,
                detail: "the detection could not be written down as text"
            )
        }
        return text
    }
}
