public struct DiagnosticCode: Hashable, Sendable, Codable, CustomStringConvertible,
    ExpressibleByIntegerLiteral
{
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public init(integerLiteral raw: UInt32) {
        self.raw = raw
    }

    public init?(parsing text: String) {
        guard text.hasPrefix(Self.prefix) else { return nil }
        let digits = text.dropFirst(Self.prefix.count)
        guard !digits.isEmpty, digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
            let value = UInt32(digits)
        else { return nil }
        raw = value
    }

    private static let prefix = "SNP-"

    private static let minimumDigits = 4

    public var description: String {
        var digits = String(raw)
        while digits.count < Self.minimumDigits {
            digits = "0" + digits
        }
        return Self.prefix + digits
    }
}

public enum LogLevel: UInt8, Comparable, CaseIterable, Sendable, Codable {
    case debug = 0
    case info
    case notice
    case warning
    case error
    case fault

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}
