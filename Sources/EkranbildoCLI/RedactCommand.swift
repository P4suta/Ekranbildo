import EkranbildoContracts
import EkranbildoImaging
import EkranbildoRedaction
import Foundation

public struct RedactOptions: Sendable, Equatable {
    public let input: String
    public let pngOutput: String?
    public let reportOutput: String?
    public let style: MaskStyle

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(code: CommandError.missingInput, detail: "a screenshot is required")
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }
        self.input = input
        pngOutput = parsed.value(of: "--png")
        reportOutput = parsed.value(of: "--report")

        if let name = parsed.value(of: "--style") {
            guard let chosen = MaskStyle(rawValue: name) else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: """
                        --style must be one of \
                        \(MaskStyle.allCases.map(\.rawValue).joined(separator: ", ")), \
                        got '\(name)'
                        """
                )
            }
            style = chosen
        } else {
            style = Defaults.style
        }
    }

    static let knownFlags = ["--png", "--report", "--style"]

    public enum Defaults {
        public static let style = MaskStyle.pixelate
    }
}

public struct RedactOutputs: Sendable, Equatable {
    public let png: [UInt8]?
    public let report: String
    public let maskCount: Int
    public let failureCount: Int
}

public struct RedactCommand: Sendable {
    private let provider: any SemanticProvider

    public init(textProvider: any SemanticProvider) {
        provider = textProvider
    }

    public func run(imageBytes: [UInt8], options: RedactOptions) throws -> RedactOutputs {
        let image = try ImageCodec.decode(imageBytes).image
        let semantics = try provider.analyse(image)

        let masks = MaskSuggester(style: options.style).masks(in: semantics.elements)
        let redactor = Redactor()
        let covered = redactor.apply(masks, to: image)
        let failures = redactor.verify(masks, original: image, masked: covered)

        return RedactOutputs(
            png: options.pngOutput == nil ? nil : try ImageCodec.encodePNG(covered),
            report: Self.report(masks: masks, failures: failures, semantics: semantics),
            maskCount: masks.count,
            failureCount: failures.count
        )
    }

    static func report(
        masks: [Mask],
        failures: [MaskFailure],
        semantics: SceneSemantics
    ) -> String {
        var lines = [
            "lines read \(semantics.elements.count { $0.kind == .text })",
            "masks \(masks.count)",
        ]
        lines.append(
            contentsOf: masks.map { "mask \($0.style.rawValue) \($0.rect.canonicalText)" }
        )
        if failures.isEmpty {
            lines.append("every mask took")
        } else {
            lines.append(contentsOf: failures.map { "FAILED \($0.rect.canonicalText): \($0.reason)" })
        }
        return lines.joined(separator: "\n")
    }
}
