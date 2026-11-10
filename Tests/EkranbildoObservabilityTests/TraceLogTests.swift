@testable import EkranbildoObservability
import EkranbildoTestKit
import Testing

@Suite("Ticks")
struct TicksTests {

    @Test("Ticks compare and subtract as a monotonic counter")
    func arithmetic() {
        let early = Ticks(nanoseconds: 1_000)
        let late = Ticks(nanoseconds: 3_500)
        #expect(early < late)
        #expect(late.interval(since: early).nanoseconds == 2_500)
        #expect(early.advanced(by: TickInterval(nanoseconds: 2_500)) == late)
    }

    @Test("Intervals convert to milliseconds for reporting")
    func milliseconds() {
        #expect(TickInterval(nanoseconds: 1_500_000).milliseconds == 1.5)
    }

    @Test("A manual tick source advances by a fixed step so traces are reproducible")
    func manualTickSource() {
        var source = ManualTickSource(start: Ticks(nanoseconds: 0), step: TickInterval(nanoseconds: 10))
        #expect(source.now() == Ticks(nanoseconds: 0))
        #expect(source.now() == Ticks(nanoseconds: 10))
        #expect(source.now() == Ticks(nanoseconds: 20))
    }

    @Test("A manual tick source can be advanced explicitly")
    func manualAdvance() {
        var source = ManualTickSource(start: Ticks(nanoseconds: 100), step: .zero)
        #expect(source.now() == Ticks(nanoseconds: 100))
        source.advance(by: TickInterval(nanoseconds: 55))
        #expect(source.now() == Ticks(nanoseconds: 155))
    }
}

@Suite("TraceLog")
struct TraceLogTests {

    private func makeLog() -> TraceLog<ManualTickSource> {
        TraceLog(ticks: ManualTickSource(start: Ticks(nanoseconds: 0), step: TickInterval(nanoseconds: 1)))
    }

    @Test("Events are recorded in the order they happen")
    func eventOrder() {
        var log = makeLog()
        log.event("first")
        log.event("second")
        log.event("third")
        #expect(log.records.map(\.name) == ["first", "second", "third"])
    }

    @Test("Each record carries the tick at which it was made")
    func timestamps() {
        var log = makeLog()
        log.event("a")
        log.event("b")
        #expect(log.records.map(\.at) == [Ticks(nanoseconds: 0), Ticks(nanoseconds: 1)])
    }

    @Test("Events carry canonical attributes")
    func attributes() {
        var log = makeLog()
        log.event("solve", attributes: [.of("candidates", .int(24)), .of("annotation", .string("a1"))])
        #expect(log.records[0].attributes.keys == ["annotation", "candidates"])
    }

    @Test("Spans nest and record their depth")
    func spanNesting() {
        var log = makeLog()
        let outer = log.beginSpan("outer")
        let inner = log.beginSpan("inner")
        log.event("work")
        log.endSpan()
        log.endSpan()

        #expect(log.records.map(\.depth) == [0, 1, 2, 1, 0])
        #expect(outer != inner)
        #expect(log.openSpanCount == 0)
    }

    @Test("Closing a span yields its duration")
    func spanDuration() {
        var log = TraceLog(
            ticks: ManualTickSource(start: Ticks(nanoseconds: 0), step: TickInterval(nanoseconds: 100))
        )
        _ = log.beginSpan("work")
        log.event("midway")
        log.endSpan()

        #expect(log.completedSpans.count == 1)
        let span = log.completedSpans[0]
        #expect(span.name == "work")
        #expect(span.duration.nanoseconds == 200)
    }

    @Test("Nested spans each get their own duration")
    func nestedSpanDurations() {
        var log = TraceLog(
            ticks: ManualTickSource(start: Ticks(nanoseconds: 0), step: TickInterval(nanoseconds: 10))
        )
        _ = log.beginSpan("outer")
        _ = log.beginSpan("inner")
        log.endSpan()
        log.endSpan()

        let byName = log.completedSpans
        #expect(byName.map(\.name) == ["inner", "outer"])
        #expect(byName[0].duration.nanoseconds == 10)
        #expect(byName[1].duration.nanoseconds == 30)
    }

    @Test("Ending a span that was never begun is recorded rather than trapping")
    func unbalancedEnd() {
        var log = makeLog()
        log.endSpan()
        #expect(log.openSpanCount == 0)
        #expect(log.anomalies.count == 1)
        #expect(log.completedSpans.isEmpty)
    }

    @Test("Spans still open when the log is finished are reported")
    func unclosedSpans() {
        var log = makeLog()
        _ = log.beginSpan("never closed")
        #expect(log.openSpanCount == 1)
        let anomalies = log.finish()
        #expect(anomalies.count == 1)
        #expect(log.openSpanCount == 0)
        #expect(log.completedSpans.map(\.name) == ["never closed"])
    }

    @Test("The canonical rendering is stable and indented by span depth")
    func canonicalRendering() {
        var log = makeLog()
        _ = log.beginSpan("solve", attributes: [.of("n", .int(2))])
        log.event("candidate", attributes: [.of("score", .double(0.5))])
        log.endSpan()

        #expect(
            log.canonicalText == """
                [0] begin solve n=2
                [1]   candidate score=0.5
                [2] end solve
                """
        )
    }

    @Test("The same sequence of calls always produces the same text")
    func renderingIsReproducible() {
        func build() -> String {
            var log = makeLog()
            _ = log.beginSpan("a", attributes: [.of("z", .int(1)), .of("y", .int(2))])
            log.event("b", attributes: [.of("m", .bool(false))])
            log.endSpan()
            return log.canonicalText
        }
        #expect(isReproducible(build))
    }
}

@Suite("Diagnostics")
struct DiagnosticTests {

    @Test("Diagnostic codes render with a fixed width so they are greppable")
    func rendering() {
        #expect(DiagnosticCode(1).description == "SNP-0001")
        #expect(DiagnosticCode(42).description == "SNP-0042")
        #expect(DiagnosticCode(9999).description == "SNP-9999")
        #expect(DiagnosticCode(12345).description == "SNP-12345")
    }

    @Test("Codes round-trip through their textual form")
    func roundTrip() {
        for raw in [UInt32(1), 42, 9999, 12345] {
            let code = DiagnosticCode(raw)
            #expect(DiagnosticCode(parsing: code.description) == code)
        }
    }

    @Test("Malformed text does not parse")
    func rejectsMalformed() {
        #expect(DiagnosticCode(parsing: "SNP-") == nil)
        #expect(DiagnosticCode(parsing: "0001") == nil)
        #expect(DiagnosticCode(parsing: "XYZ-0001") == nil)
        #expect(DiagnosticCode(parsing: "SNP-abcd") == nil)
    }

    @Test("Log levels order from least to most severe")
    func logLevelOrdering() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.notice)
        #expect(LogLevel.notice < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(LogLevel.error < LogLevel.fault)
        #expect(LogLevel.allCases.count == 6)
    }
}
