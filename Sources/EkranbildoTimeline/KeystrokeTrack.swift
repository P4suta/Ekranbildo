import EkranbildoContracts

public struct KeystrokeRow: Hashable, Sendable, Codable {
    public let from: Timestamp
    public let until: Timestamp
    public let caps: [String]

    public init(from: Timestamp, until: Timestamp, caps: [String]) {
        self.from = from
        self.until = until
        self.caps = caps
    }

    public func covers(_ moment: Timestamp) -> Bool { from <= moment && moment < until }
}

public struct KeystrokeTrack: Hashable, Sendable, Codable {
    public let rows: [KeystrokeRow]

    public init(rows: [KeystrokeRow]) {
        self.rows = rows
    }

    public enum Defaults {
        public static let holdFor = Timestamp.seconds(1.2)
        public static let joinWithin = Timestamp.seconds(1)
        public static let mostCaps = 8
    }

    public init(
        recorded keys: [Keystroke],
        holdFor: Timestamp = Defaults.holdFor,
        joinWithin: Timestamp = Defaults.joinWithin,
        mostCaps: Int = Defaults.mostCaps
    ) {
        let ordered = keys.sorted {
            $0.at == $1.at ? $0.written < $1.written : $0.at < $1.at
        }

        var built: [KeystrokeRow] = []
        var caps: [String] = []
        var started = Timestamp.zero
        var last = Timestamp.zero

        func close(at ending: Timestamp) {
            guard !caps.isEmpty else { return }
            built.append(
                KeystrokeRow(
                    from: started,
                    until: .seconds(ending.seconds + holdFor.seconds),
                    caps: caps
                ))
            caps = []
        }

        for key in ordered {
            let joins =
                !caps.isEmpty && key.isPlain
                && key.at.seconds - last.seconds <= joinWithin.seconds
            if !joins {
                close(at: last)
                started = key.at
            }
            caps.append(key.written)
            if caps.count > mostCaps { caps.removeFirst(caps.count - mostCaps) }
            last = key.at
            if !key.isPlain {
                close(at: last)
            }
        }
        close(at: last)

        rows = Self.trimmed(built)
    }

    static func trimmed(_ rows: [KeystrokeRow]) -> [KeystrokeRow] {
        rows.enumerated().map { place, row in
            let next = place + 1 < rows.count ? rows[place + 1].from : nil
            guard let next, next < row.until else { return row }
            return KeystrokeRow(from: row.from, until: next, caps: row.caps)
        }
    }

    public func showing(at moment: Timestamp) -> [String] {
        for row in rows where row.covers(moment) {
            return row.caps
        }
        return []
    }
}
