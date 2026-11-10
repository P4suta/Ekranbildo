import EkranbildoContracts
import EkranbildoGeometry

public enum CaptureTag: Sendable {}
public typealias CaptureID = StableID<CaptureTag>

public struct LibraryEntry: Hashable, Sendable, Codable, Identifiable {
    public let id: CaptureID
    public let takenAt: Timestamp
    public let image: ImageRef
    public let canvas: Size
    public let seconds: Double?
    public let source: Source

    public enum Source: String, Hashable, Sendable, Codable {
        case region
        case window
        case display
        case scroll
        case recording
        case imported
    }

    public init(
        id: CaptureID,
        takenAt: Timestamp,
        image: ImageRef,
        canvas: Size,
        seconds: Double? = nil,
        source: Source
    ) {
        self.id = id
        self.takenAt = takenAt
        self.image = image
        self.canvas = canvas
        self.seconds = seconds
        self.source = source
    }
}

public struct Library: Hashable, Sendable, Codable {
    public private(set) var entries: [LibraryEntry]
    public let limit: Int

    public init(entries: [LibraryEntry] = [], limit: Int = Defaults.limit) {
        self.limit = max(1, limit)
        self.entries = Self.ordered(entries)
    }

    public enum Defaults {
        public static let limit = 200
    }

    public var newest: LibraryEntry? { entries.first }

    @discardableResult
    public mutating func add(_ entry: LibraryEntry) -> [LibraryEntry] {
        entries = Self.ordered(entries + [entry])
        guard entries.count > limit else { return [] }

        let dropped = Array(entries[limit...])
        entries = Array(entries[..<limit])
        return dropped
    }

    public func entry(_ id: CaptureID) -> LibraryEntry? {
        entries.first { $0.id == id }
    }

    @discardableResult
    public mutating func remove(_ id: CaptureID) -> LibraryEntry? {
        guard let found = entry(id) else { return nil }
        entries.removeAll { $0.id == id }
        return found
    }

    @discardableResult
    public mutating func clear() -> [LibraryEntry] {
        let all = entries
        entries = []
        return all
    }

    static func ordered(_ entries: [LibraryEntry]) -> [LibraryEntry] {
        entries.sorted {
            $0.takenAt == $1.takenAt ? $0.id.raw > $1.id.raw : $0.takenAt > $1.takenAt
        }
    }
}
