public struct SpanID: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let raw: UInt32

    public init(_ raw: UInt32) {
        self.raw = raw
    }

    public static func < (a: Self, b: Self) -> Bool { a.raw < b.raw }

    public var description: String { "span#\(raw)" }
}

public struct TraceRecord: Hashable, Sendable, Codable {
    public enum Kind: Hashable, Sendable, Codable {
        case event
        case spanBegan(SpanID)
        case spanEnded(SpanID)
    }

    public let kind: Kind
    public let name: String
    public let attributes: TraceAttributes
    public let at: Ticks
    public let depth: Int
}

public struct CompletedSpan: Hashable, Sendable, Codable {
    public let id: SpanID
    public let parent: SpanID?
    public let name: String
    public let attributes: TraceAttributes
    public let start: Ticks
    public let end: Ticks
    public let duration: TickInterval
}

public struct TraceAnomaly: Hashable, Sendable, Codable {
    public let code: DiagnosticCode
    public let detail: String
    public let at: Ticks

    public static let unbalancedEnd: DiagnosticCode = 1
    public static let spanLeftOpen: DiagnosticCode = 2
}

public struct TraceLog<Clock: TickSource>: Sendable {
    public private(set) var records: [TraceRecord] = []
    public private(set) var completedSpans: [CompletedSpan] = []
    public private(set) var anomalies: [TraceAnomaly] = []

    private var clock: Clock
    private var openSpans: [OpenSpan] = []
    private var nextSpanID: UInt32 = 1
    private let signposts: any SignpostEmitting

    private struct OpenSpan {
        let id: SpanID
        let parent: SpanID?
        let name: String
        let attributes: TraceAttributes
        let start: Ticks
    }

    public init(ticks: Clock, signposts: any SignpostEmitting = NoSignposts()) {
        clock = ticks
        self.signposts = signposts
    }

    public var openSpanCount: Int { openSpans.count }

    public var currentSpan: SpanID? { openSpans.last?.id }

    public mutating func event(_ name: String, attributes pairs: [TraceAttributes.Entry] = []) {
        records.append(
            TraceRecord(
                kind: .event,
                name: name,
                attributes: TraceAttributes(pairs),
                at: clock.now(),
                depth: openSpans.count
            )
        )
        signposts.happened(name)
    }

    @discardableResult
    public mutating func beginSpan(
        _ name: String,
        attributes pairs: [TraceAttributes.Entry] = []
    ) -> SpanID {
        let id = SpanID(nextSpanID)
        nextSpanID &+= 1
        let attributes = TraceAttributes(pairs)
        let start = clock.now()
        signposts.began(name)

        records.append(
            TraceRecord(
                kind: .spanBegan(id),
                name: name,
                attributes: attributes,
                at: start,
                depth: openSpans.count
            )
        )
        openSpans.append(
            OpenSpan(id: id, parent: openSpans.last?.id, name: name, attributes: attributes, start: start)
        )
        return id
    }

    @discardableResult
    public mutating func endSpan() -> SpanID? {
        let at = clock.now()
        guard let span = openSpans.popLast() else {
            anomalies.append(
                TraceAnomaly(
                    code: TraceAnomaly.unbalancedEnd,
                    detail: "endSpan() called with no span open",
                    at: at
                )
            )
            return nil
        }

        records.append(
            TraceRecord(
                kind: .spanEnded(span.id),
                name: span.name,
                attributes: .empty,
                at: at,
                depth: openSpans.count
            )
        )
        completedSpans.append(
            CompletedSpan(
                id: span.id,
                parent: span.parent,
                name: span.name,
                attributes: span.attributes,
                start: span.start,
                end: at,
                duration: at.interval(since: span.start)
            )
        )
        signposts.ended(span.name)
        return span.id
    }

    @discardableResult
    public mutating func finish() -> [TraceAnomaly] {
        var reported: [TraceAnomaly] = []
        while let span = openSpans.last {
            let at = clock.now()
            let anomaly = TraceAnomaly(
                code: TraceAnomaly.spanLeftOpen,
                detail: "span '\(span.name)' was still open when the trace finished",
                at: at
            )
            reported.append(anomaly)
            anomalies.append(anomaly)
            endSpan()
        }
        return reported
    }

    public func synthesised(_ replacing: (String) -> String) -> Self {
        var copy = self
        copy.records = records.map { record in
            TraceRecord(
                kind: record.kind,
                name: record.name,
                attributes: record.attributes.synthesised(replacing),
                at: record.at,
                depth: record.depth
            )
        }
        copy.completedSpans = completedSpans.map { span in
            CompletedSpan(
                id: span.id,
                parent: span.parent,
                name: span.name,
                attributes: span.attributes.synthesised(replacing),
                start: span.start,
                end: span.end,
                duration: span.duration
            )
        }
        return copy
    }

    public var canonicalText: String {
        records.enumerated()
            .map { index, record in
                let indent = String(repeating: "  ", count: record.depth)
                let prefix: String
                switch record.kind {
                case .event: prefix = ""
                case .spanBegan: prefix = "begin "
                case .spanEnded: prefix = "end "
                }
                let attributes = record.attributes.isEmpty ? "" : " " + record.attributes.canonicalText
                return "[\(index)] \(indent)\(prefix)\(record.name)\(attributes)"
            }
            .joined(separator: "\n")
    }
}
