import EkranbildoGeometry
import Foundation

public enum UnknownValue: Hashable, Sendable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([Self])
    case object(Lookup<String, Self>)

    public init(from decoder: any Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let value = try? single.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? single.decode(Double.self) {
            self = .number(value)
        } else if let value = try? single.decode(String.self) {
            self = .string(value)
        } else if let value = try? single.decode([Self].self) {
            self = .array(value)
        } else {
            self = .object(try single.decode(Lookup<String, Self>.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .null: try single.encodeNil()
        case .bool(let value): try single.encode(value)
        case .number(let value): try single.encode(value)
        case .string(let value): try single.encode(value)
        case .array(let value): try single.encode(value)
        case .object(let value): try single.encode(value)
        }
    }
}

public struct UnknownEntry: Hashable, Sendable {
    public let key: String
    public let value: UnknownValue

    public init(key: String, value: UnknownValue) {
        self.key = key
        self.value = value
    }
}

public struct UnknownKeys: Hashable, Sendable {
    public let entries: [UnknownEntry]

    public init(entries: [UnknownEntry]) {
        self.entries = entries.sorted { $0.key < $1.key }
    }

    public var isEmpty: Bool { entries.isEmpty }

    public static func read(from decoder: any Decoder, known: NameSet) throws -> Self {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var found: [UnknownEntry] = []
        for key in container.allKeys where !known.contains(key.stringValue) {
            found.append(
                UnknownEntry(
                    key: key.stringValue,
                    value: try container.decode(UnknownValue.self, forKey: key)
                ))
        }
        return Self(entries: found)
    }

    public func write(to encoder: any Encoder) throws {
        guard !isEmpty else { return }
        var container = encoder.container(keyedBy: AnyKey.self)
        for entry in entries {
            try container.encode(entry.value, forKey: AnyKey(entry.key))
        }
    }

    public static let nothing = Self(entries: [])
}

struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

public struct UnplacedReason: Hashable, Sendable {
    public let annotation: AnnotationID
    public let reason: String

    public init(annotation: AnnotationID, reason: String) {
        self.annotation = annotation
        self.reason = reason
    }
}
