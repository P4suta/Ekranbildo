import EkranbildoContracts

public struct PointerReading: Hashable, Sendable {
    public let position: ScreenPoint
    public let pressed: Bool

    public init(position: ScreenPoint, pressed: Bool) {
        self.position = position
        self.pressed = pressed
    }
}

public protocol PointerReader: Sendable {
    func read() -> PointerReading?
}

public struct PointerSampler: Sendable {
    private let heartbeat: Timestamp
    private var last: (reading: PointerReading, at: Timestamp)?

    public init(heartbeat: Timestamp = Defaults.heartbeat) {
        self.heartbeat = heartbeat
    }

    public enum Defaults {
        public static let heartbeat = Timestamp.seconds(0.25)
    }

    public mutating func sample(_ reading: PointerReading?, at moment: Timestamp) -> CursorSample? {
        guard let reading else { return nil }

        if let last {
            guard moment > last.at else { return nil }

            let moved = reading.position != last.reading.position
            let changed = reading.pressed != last.reading.pressed
            let overdue =
                moment.nanoseconds - last.at.nanoseconds >= heartbeat.nanoseconds
            guard moved || changed || overdue else { return nil }
        }

        last = (reading, moment)
        return CursorSample(at: moment, position: reading.position, pressed: reading.pressed)
    }
}
