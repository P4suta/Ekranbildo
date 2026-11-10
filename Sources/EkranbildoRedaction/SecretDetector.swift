import Foundation

public struct Secret: Hashable, Sendable {
    public let kind: Kind
    public let range: Range<String.Index>

    public enum Kind: String, Hashable, Sendable, Codable, CaseIterable {
        case emailAddress
        case apiKey
        case jsonWebToken
        case paymentCard
        case networkAddress
    }

    public init(kind: Kind, range: Range<String.Index>) {
        self.kind = kind
        self.range = range
    }
}

public struct SecretDetector: Sendable {
    private let kinds: [Secret.Kind]

    public init(kinds: [Secret.Kind] = Secret.Kind.allCases) {
        self.kinds = kinds
    }

    public func secrets(in text: String) -> [Secret] {
        guard !text.isEmpty else { return [] }

        var found: [Secret] = []
        for kind in kinds {
            for range in Self.matches(of: kind, in: text) where Self.isReal(kind, text[range]) {
                found.append(Secret(kind: kind, range: range))
            }
        }

        return found.sorted {
            $0.range.lowerBound == $1.range.lowerBound
                ? $0.kind.rawValue < $1.kind.rawValue
                : $0.range.lowerBound < $1.range.lowerBound
        }
    }

    private static func matches(of kind: Secret.Kind, in text: String) -> [Range<String.Index>] {
        guard let expression = try? NSRegularExpression(pattern: Patterns.pattern(for: kind)) else {
            return []
        }
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: whole)
            .compactMap { Range($0.range, in: text) }
    }

    static func isReal(_ kind: Secret.Kind, _ text: Substring) -> Bool {
        switch kind {
        case .paymentCard:
            passesLuhn(text)
        case .emailAddress, .apiKey, .jsonWebToken, .networkAddress:
            true
        }
    }

    static func passesLuhn(_ text: Substring) -> Bool {
        let digits = text.compactMap(\.wholeNumberValue)
        guard digits.count >= Luhn.shortestCard else { return false }

        var total = 0
        for (position, digit) in digits.reversed().enumerated() {
            guard position.isMultiple(of: Luhn.everyOther) else {
                let doubled = digit * Luhn.everyOther
                total += doubled > Luhn.largestDigit ? doubled - Luhn.largestDigit : doubled
                continue
            }
            total += digit
        }
        return total.isMultiple(of: Luhn.modulus)
    }

    private enum Luhn {
        static let shortestCard = 13
        static let everyOther = 2
        static let largestDigit = 9
        static let modulus = 10
    }

    enum Patterns {
        static func pattern(for kind: Secret.Kind) -> String {
            switch kind {
            case .emailAddress:
                #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#

            case .jsonWebToken:
                #"eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+"#

            case .apiKey:
                #"\b(?:AKIA|ASIA|AROA|AIDA|ANPA|ANVA|ABIA|ACCA)[A-Z0-9]{16}\b"#
                    + #"|[A-Za-z0-9_\-]*[A-Za-z][A-Za-z0-9_\-]{29,}"#

            case .paymentCard:
                #"\b(?:\d[ \-]?){12,18}\d\b"#

            case .networkAddress:
                #"\b(?:\d{1,3}\.){3}\d{1,3}\b|\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b"#
            }
        }
    }
}
