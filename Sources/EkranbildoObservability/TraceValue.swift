public enum TraceValue: Hashable, Sendable, Codable {
    case string(String)
    case borrowed(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    indirect case list([Self])

    public var canonicalText: String {
        switch self {
        case .string(let text):
            return "\"\(Self.escape(text))\""
        case .borrowed(let text):
            return "~\"\(Self.escape(text))\""
        case .int(let value):
            return String(value)
        case .double(let value):
            return Self.canonicalDouble(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .list(let values):
            return "[" + values.map(\.canonicalText).joined(separator: ", ") + "]"
        }
    }

    static func canonicalDouble(_ value: Double) -> String { CanonicalText.double(value) }

    static func escape(_ text: String) -> String { CanonicalText.escaped(text) }
}

public struct TraceAttributes: Hashable, Sendable, Codable {
    public private(set) var entries: [Entry]

    private struct Ordered {
        let offset: Int
        let entry: Entry

        var key: String { entry.key }
        var value: TraceValue { entry.value }
    }

    public struct Entry: Hashable, Sendable, Codable {
        public let key: String
        public let value: TraceValue

        public init(key: String, value: TraceValue) {
            self.key = key
            self.value = value
        }

        public static func of(_ key: String, _ value: TraceValue) -> Self {
            Self(key: key, value: value)
        }
    }

    public init(_ given: [Entry]) {
        let indexed = given.enumerated().map {
            Ordered(offset: $0.offset, entry: $0.element)
        }
        let sorted = indexed.sorted { lhs, rhs in
            lhs.key == rhs.key ? lhs.offset < rhs.offset : lhs.key < rhs.key
        }

        var deduplicated: [Entry] = []
        deduplicated.reserveCapacity(sorted.count)
        for item in sorted {
            if deduplicated.last?.key == item.key {
                deduplicated[deduplicated.count - 1] = Entry(key: item.key, value: item.value)
            } else {
                deduplicated.append(Entry(key: item.key, value: item.value))
            }
        }
        entries = deduplicated
    }

    public static let empty = Self([])

    public var isEmpty: Bool { entries.isEmpty }
    public var keys: [String] { entries.map(\.key) }

    public subscript(key: String) -> TraceValue? {
        entries.first { $0.key == key }?.value
    }

    public func merging(_ overrides: Self) -> Self {
        Self(entries + overrides.entries)
    }

    public var canonicalText: String {
        entries.map { "\($0.key)=\($0.value.canonicalText)" }.joined(separator: " ")
    }
}

extension TraceValue {
    public func synthesised(_ replacing: (String) -> String) -> Self {
        switch self {
        case .borrowed(let text): .borrowed(replacing(text))
        case .list(let values): .list(values.map { $0.synthesised(replacing) })
        case .string, .int, .double, .bool: self
        }
    }
}

extension TraceAttributes {
    public func synthesised(_ replacing: (String) -> String) -> Self {
        Self(entries.map { .of($0.key, $0.value.synthesised(replacing)) })
    }
}
