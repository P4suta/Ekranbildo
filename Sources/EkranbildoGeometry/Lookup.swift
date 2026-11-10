public struct Lookup<Key: Hashable, Value> {
    private var pairs: [Key: Value]

    public init() {
        pairs = [:]
    }

    public init(_ pairs: [Key: Value]) {
        self.pairs = pairs
    }

    public subscript(key: Key) -> Value? {
        get { pairs[key] }
        set { pairs[key] = newValue }
    }

    public var count: Int { pairs.count }
    public var isEmpty: Bool { pairs.isEmpty }

    public mutating func removeAll() {
        pairs.removeAll()
    }

    public struct Pair {
        public let key: Key
        public let value: Value

        public init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
}

extension Lookup where Key: Comparable {
    public var sortedKeys: [Key] { pairs.keys.sorted() }

    public var sortedPairs: [Pair] {
        sortedKeys.compactMap { key in pairs[key].map { Pair(key: key, value: $0) } }
    }
}

extension Lookup: Sendable where Key: Sendable, Value: Sendable {}

extension Lookup: Encodable where Key: Encodable, Value: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try pairs.encode(to: encoder)
    }
}

extension Lookup: Decodable where Key: Decodable, Value: Decodable {
    public init(from decoder: any Decoder) throws {
        pairs = try [Key: Value](from: decoder)
    }
}

extension Lookup: Equatable where Value: Equatable {
    public static func == (a: Self, b: Self) -> Bool { a.pairs == b.pairs }
}

extension Lookup: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pairs)
    }
}

public struct NameSet: ExpressibleByArrayLiteral, Hashable, Sendable {
    private let names: Set<String>

    public init() {
        names = []
    }

    public init(_ names: some Collection<String>) {
        self.names = Set(names)
    }

    public init(arrayLiteral names: String...) {
        self.names = Set(names)
    }

    public func contains(_ name: String) -> Bool { names.contains(name) }

    public var count: Int { names.count }
    public var isEmpty: Bool { names.isEmpty }
    public var sorted: [String] { names.sorted() }

    public func adding(_ name: String) -> Self {
        Self(names.union([name]))
    }

    public func adding(_ other: Self) -> Self {
        Self(names.union(other.names))
    }
}
