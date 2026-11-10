public struct Ticks: Hashable, Comparable, Sendable, Codable {
    public let nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static let zero = Self(nanoseconds: 0)

    public static func < (a: Self, b: Self) -> Bool { a.nanoseconds < b.nanoseconds }

    public func interval(since earlier: Self) -> TickInterval {
        TickInterval(nanoseconds: nanoseconds - earlier.nanoseconds)
    }

    public func advanced(by interval: TickInterval) -> Self {
        Self(nanoseconds: nanoseconds &+ interval.nanoseconds)
    }
}

public struct TickInterval: Hashable, Comparable, Sendable, Codable {
    public let nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static let zero = Self(nanoseconds: 0)

    public static func < (a: Self, b: Self) -> Bool {
        a.nanoseconds < b.nanoseconds
    }

    private static let nanosecondsPerMillisecond: Double = 1_000_000

    public var milliseconds: Double { Double(nanoseconds) / Self.nanosecondsPerMillisecond }
}

public protocol TickSource: Sendable {
    mutating func now() -> Ticks
}

public struct ManualTickSource: TickSource, Sendable, Equatable {
    private var current: Ticks
    private let step: TickInterval

    public init(start: Ticks = .zero, step: TickInterval = TickInterval(nanoseconds: 1)) {
        current = start
        self.step = step
    }

    public mutating func now() -> Ticks {
        let value = current
        current = current.advanced(by: step)
        return value
    }

    public var next: Ticks { current }

    public mutating func advance(by interval: TickInterval) {
        current = current.advanced(by: interval)
    }
}
