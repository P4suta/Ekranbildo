import CoreGraphics
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoObservability
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportFormat: String, Hashable, Sendable, Codable, CaseIterable {
    case png
    case jpeg
    case pdf

    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .pdf: .pdf
        }
    }

    public func matchesSignature(of bytes: [UInt8]) -> Bool {
        let signature = Self.signature(of: self)
        return Array(bytes.prefix(signature.count)) == signature
    }

    private enum Signature {
        static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        static let jpeg: [UInt8] = [0xFF, 0xD8, 0xFF]
        static let pdf: [UInt8] = [0x25, 0x50, 0x44, 0x46]
    }

    private static func signature(of format: Self) -> [UInt8] {
        switch format {
        case .png: Signature.png
        case .jpeg: Signature.jpeg
        case .pdf: Signature.pdf
        }
    }
}

public struct ExportError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public static let nothingToExport: DiagnosticCode = 800
    public static let writeFailed: DiagnosticCode = 801
}

public struct Exporter: Sendable {
    private let quality: Double

    public init(quality: Double = Defaults.quality) {
        self.quality = min(1, max(0, quality))
    }

    public enum Defaults {
        public static let quality: Double = 0.92
    }

    public func export(_ image: ImageBuffer, as format: ExportFormat) throws -> [UInt8] {
        guard image.isWellFormed, !image.isEmpty else {
            throw ExportError(
                code: ExportError.nothingToExport,
                detail: "there is no picture to write"
            )
        }

        switch format {
        case .png, .jpeg:
            return try writeImage(image, as: format)
        case .pdf:
            return try writePDF(image)
        }
    }

    private func writeImage(_ image: ImageBuffer, as format: ExportFormat) throws -> [UInt8] {
        let cgImage = try ImageCodec.cgImage(of: image)
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, format.type.identifier as CFString, 1, nil)
        else {
            throw ExportError(
                code: ExportError.writeFailed,
                detail: "the system would not write a \(format.rawValue)"
            )
        }

        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError(
                code: ExportError.writeFailed,
                detail: "the \(format.rawValue) could not be finished"
            )
        }
        return [UInt8](data as Data)
    }

    private func writePDF(_ image: ImageBuffer) throws -> [UInt8] {
        let cgImage = try ImageCodec.cgImage(of: image)
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: image.width, height: image.height)

        guard let consumer = CGDataConsumer(data: data),
            let context = CGContext(consumer: consumer, mediaBox: &box, nil)
        else {
            throw ExportError(
                code: ExportError.writeFailed,
                detail: "the system would not start a page"
            )
        }

        context.beginPDFPage(nil)
        context.draw(cgImage, in: box)
        context.endPDFPage()
        context.closePDF()

        return Self.withoutTimestamps([UInt8](data as Data))
    }

    static func withoutTimestamps(_ bytes: [UInt8]) -> [UInt8] {
        var result = bytes
        blank(&result, after: Array(Markers.creationDate.utf8), until: Markers.closingParenthesis)
        blank(&result, after: Array(Markers.identifier.utf8), until: Markers.closingBracket)
        return result
    }

    private static func blank(_ bytes: inout [UInt8], after marker: [UInt8], until end: UInt8) {
        var index = 0
        while index + marker.count < bytes.count {
            guard Array(bytes[index..<(index + marker.count)]) == marker else {
                index += 1
                continue
            }
            var position = index + marker.count
            while position < bytes.count, bytes[position] != end {
                bytes[position] = Markers.filler
                position += 1
            }
            index = position
        }
    }

    private enum Markers {
        static let creationDate = "/CreationDate ("
        static let identifier = "/ID [ "
        static let closingParenthesis: UInt8 = 0x29
        static let closingBracket: UInt8 = 0x5D
        static let filler: UInt8 = 0x30
    }

    public static let identifyingDictionaries: [String] = [
        "{GPS}",
        "{TIFF}",
        "{IPTC}",
        "{MakerApple}",
        "{ExifAux}",
    ]

    public static let identifyingFields: [String] = [
        "DateTime",
        "DateTimeOriginal",
        "DateTimeDigitized",
        "Make",
        "Model",
        "Software",
        "HostComputer",
        "Artist",
        "Copyright",
        "UserComment",
        "LensMake",
        "LensModel",
        "SerialNumber",
        "BodySerialNumber",
    ]

    public static let identifyingProperties: [String] =
        identifyingDictionaries + identifyingFields

    public static func identifyingContent(in properties: [String: Any]) -> [String] {
        var found: [String] = []
        for name in identifyingDictionaries where properties[name] != nil {
            found.append(name)
        }
        for (key, value) in properties {
            guard let nested = value as? [String: Any] else {
                if identifyingFields.contains(key) { found.append(key) }
                continue
            }
            for field in identifyingFields where nested[field] != nil {
                found.append("\(key).\(field)")
            }
        }
        return found.sorted()
    }

    public static func containsSelectableText(_ bytes: [UInt8]) -> Bool {
        TextOperators.all.contains { bytes.contains(Array($0.utf8)) }
    }

    private enum TextOperators {
        static let all = ["BT", "Tj", "TJ"]
    }
}
