public struct DeterministicSum: Sendable, Equatable {
    @usableFromInline var parts: [Double]

    public init() {
        parts = []
    }

    public init(_ values: [Double]) {
        parts = values
    }

    public mutating func add(_ value: Double) {
        parts.append(value)
    }

    public var count: Int { parts.count }

    public func value() -> Double {
        Self.pairwiseReduce(parts)
    }

    public static func pairwiseReduce(_ values: [Double]) -> Double {
        if values.isEmpty { return 0 }
        let pairSize = 2
        var buffer = values
        while buffer.count > 1 {
            var folded: [Double] = []
            folded.reserveCapacity((buffer.count + 1) / pairSize)
            var index = 0
            while index + 1 < buffer.count {
                folded.append(buffer[index] + buffer[index + 1])
                index += pairSize
            }
            if index < buffer.count {
                folded.append(buffer[index])
            }
            buffer = folded
        }
        return buffer[0]
    }
}

public enum Tolerance {
    public static let geometric: Double = 1e-9
    public static let area: Double = 1e-9
    public static let overlapEpsilon: Double = 1e-9
}

@inlinable
public func approximatelyEqual(
    _ a: Double,
    _ b: Double,
    tolerance: Double = Tolerance.geometric
) -> Bool {
    if a == b { return true }
    let difference = a - b
    return difference < 0 ? -difference <= tolerance : difference <= tolerance
}

public enum ApproximateOrder: Sendable, Equatable {
    case ascending
    case tie
    case descending
}

@inlinable
public func approximateCompare(
    _ a: Double,
    _ b: Double,
    tolerance: Double = Tolerance.geometric
) -> ApproximateOrder {
    let difference = a - b
    if difference < 0 {
        return -difference <= tolerance ? .tie : .ascending
    } else {
        return difference <= tolerance ? .tie : .descending
    }
}

public struct StableID<Tag>: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public static func < (a: StableID<Tag>, b: StableID<Tag>) -> Bool { a.raw < b.raw }

    public var description: String { "#\(raw)" }
}

public struct IDAllocator<Tag>: Sendable, Equatable, Codable {
    private var cursor: UInt32

    public init(startingAt start: UInt32 = 1) {
        cursor = start
    }

    public mutating func allocate() -> StableID<Tag> {
        let allocated = StableID<Tag>(cursor)
        cursor &+= 1
        return allocated
    }

    public var peek: UInt32 { cursor }
}

public struct SplitMix64: RandomNumberGenerator, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= Constants.increment
        var z = state
        z = (z ^ (z >> Constants.firstShift)) &* Constants.firstMultiplier
        z = (z ^ (z >> Constants.secondShift)) &* Constants.secondMultiplier
        return z ^ (z >> Constants.finalShift)
    }

    private enum Constants {
        static let increment: UInt64 = 0x9E37_79B9_7F4A_7C15
        static let firstShift: UInt64 = 30
        static let firstMultiplier: UInt64 = 0xBF58_476D_1CE4_E5B9
        static let secondShift: UInt64 = 27
        static let secondMultiplier: UInt64 = 0x94D0_49BB_1331_11EB
        static let finalShift: UInt64 = 31
    }
}
