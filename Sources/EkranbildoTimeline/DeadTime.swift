import EkranbildoContracts

public struct ActivityWindow: Hashable, Sendable, Codable {
    public let from: Timestamp
    public let to: Timestamp
    public let changed: Bool

    public init(from: Timestamp, to: Timestamp, changed: Bool) {
        self.from = from
        self.to = to
        self.changed = changed
    }

    public var seconds: Double { to.seconds - from.seconds }
}

public struct TimeCut: Hashable, Sendable, Codable {
    public let from: Timestamp
    public let to: Timestamp

    public init(from: Timestamp, to: Timestamp) {
        self.from = from
        self.to = to
    }

    public var seconds: Double { to.seconds - from.seconds }
}

public struct DeadTimeRemover: Sendable {
    private let longestPause: Double
    private let breathingRoom: Double

    public init(
        longestPause: Double = Defaults.longestPause,
        breathingRoom: Double = Defaults.breathingRoom
    ) {
        self.longestPause = max(0, longestPause)
        self.breathingRoom = max(0, breathingRoom)
    }

    public enum Defaults {
        public static let longestPause: Double = 2
        public static let breathingRoom: Double = 0.4
    }

    public func cuts(in windows: [ActivityWindow]) -> [TimeCut] {
        windows
            .filter { !$0.changed }
            .compactMap { window in
                let from = Timestamp.seconds(window.from.seconds + breathingRoom)
                let to = Timestamp.seconds(window.to.seconds - breathingRoom)
                guard window.seconds > longestPause, to > from else { return nil }
                return TimeCut(from: from, to: to)
            }
            .sorted { $0.from == $1.from ? $0.to < $1.to : $0.from < $1.from }
    }

    public func removed(from windows: [ActivityWindow]) -> Timestamp {
        var total = 0.0
        for cut in cuts(in: windows) {
            total += cut.seconds
        }
        return .seconds(total)
    }
}
