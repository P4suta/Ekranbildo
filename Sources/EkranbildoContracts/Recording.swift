import EkranbildoObservability

public struct Timestamp: Hashable, Sendable, Codable, Comparable {
    public let nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static func < (a: Self, b: Self) -> Bool { a.nanoseconds < b.nanoseconds }

    public static let zero = Self(nanoseconds: 0)

    public var seconds: Double { Double(nanoseconds) / Double(Scale.nanosecondsPerSecond) }

    public static func seconds(_ value: Double) -> Self {
        Self(nanoseconds: Int64((value * Double(Scale.nanosecondsPerSecond)).rounded()))
    }

    private enum Scale {
        static let nanosecondsPerSecond: Int64 = 1_000_000_000
    }
}

public struct RecordedFrame: Hashable, Sendable, Codable {
    public let presentedAt: Timestamp
    public let image: ImageRef
    public let sequence: Int

    public init(presentedAt: Timestamp, image: ImageRef, sequence: Int) {
        self.presentedAt = presentedAt
        self.image = image
        self.sequence = sequence
    }
}

public struct CursorSample: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let position: ScreenPoint
    public let pressed: Bool

    public init(at: Timestamp, position: ScreenPoint, pressed: Bool) {
        self.at = at
        self.position = position
        self.pressed = pressed
    }
}

public struct RecordedCursor: Hashable, Sendable, Codable {
    public let geometry: CaptureGeometry
    public let samples: [CursorSample]

    public init(geometry: CaptureGeometry, samples: [CursorSample]) {
        self.geometry = geometry
        self.samples = samples
    }
}

public struct RecordedEvent: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let kind: Kind

    public enum Kind: String, Hashable, Sendable, Codable {
        case click
        case resumed
        case framesDropped
        case displayChanged
    }

    public init(at: Timestamp, kind: Kind) {
        self.at = at
        self.kind = kind
    }
}

public struct Recording: Hashable, Sendable, Codable {
    public let geometry: CaptureGeometry
    public let frames: [RecordedFrame]
    public let cursor: [CursorSample]
    public let events: [RecordedEvent]
    public let droppedFrameCount: Int

    public init(
        geometry: CaptureGeometry,
        frames: [RecordedFrame],
        cursor: [CursorSample],
        events: [RecordedEvent],
        droppedFrameCount: Int
    ) {
        self.geometry = geometry
        self.frames = frames
        self.cursor = cursor
        self.events = events
        self.droppedFrameCount = droppedFrameCount
    }

    public var duration: Timestamp {
        guard let first = frames.first?.presentedAt else { return .zero }
        let last = max(
            frames.last?.presentedAt ?? first,
            max(cursor.last?.at ?? first, events.last?.at ?? first)
        )
        return Timestamp(nanoseconds: last.nanoseconds - first.nanoseconds)
    }

    public var isEmpty: Bool { frames.isEmpty }
}

public struct RecordingError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let diskFull: DiagnosticCode = 700
    public static let wrongState: DiagnosticCode = 701
    public static let interrupted: DiagnosticCode = 702
}

public struct Keystroke: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let cap: String
    public let modifiers: Modifiers

    public init(at: Timestamp, cap: String, modifiers: Modifiers) {
        self.at = at
        self.cap = cap
        self.modifiers = modifiers
    }

    public var isPlain: Bool { modifiers.isEmpty }

    public var written: String {
        var text = ""
        if modifiers.contains(.control) { text += Symbols.control }
        if modifiers.contains(.option) { text += Symbols.option }
        if modifiers.contains(.shift) { text += Symbols.shift }
        if modifiers.contains(.command) { text += Symbols.command }
        return text + cap
    }

    private enum Symbols {
        static let control = "⌃"
        static let option = "⌥"
        static let shift = "⇧"
        static let command = "⌘"
    }
}
