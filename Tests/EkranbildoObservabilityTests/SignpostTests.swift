import EkranbildoObservability
import Testing

@Suite("Signposts")
struct SignpostTests {

    private func emitted(_ record: (inout TraceLog<ManualTickSource>) -> Void) -> [String] {
        let recorder = RecordingSignposts()
        var trace = TraceLog(ticks: ManualTickSource(), signposts: recorder)
        record(&trace)
        return recorder.emitted
    }

    @Test("A span begins and ends on the signpost stream too")
    func spansAreEmitted() {
        let lines = emitted { trace in
            trace.beginSpan("solve")
            _ = trace.endSpan()
        }
        #expect(lines == ["begin solve", "end solve"])
    }

    @Test("Nested spans nest there as well")
    func nestingIsKept() {
        let lines = emitted { trace in
            trace.beginSpan("render")
            trace.beginSpan("solve")
            _ = trace.endSpan()
            _ = trace.endSpan()
        }
        #expect(lines == ["begin render", "begin solve", "end solve", "end render"])
    }

    @Test("Events are emitted between the spans they happened in")
    func eventsAreEmitted() {
        let lines = emitted { trace in
            trace.beginSpan("solve")
            trace.event("placed")
            _ = trace.endSpan()
        }
        #expect(lines == ["begin solve", "event placed", "end solve"])
    }

    @Test("What a trace records does not depend on whether anybody is listening")
    func listeningChangesNothing() {
        var quiet = TraceLog(ticks: ManualTickSource())
        var watched = TraceLog(ticks: ManualTickSource(), signposts: RecordingSignposts())
        quiet.beginSpan("solve", attributes: [.of("annotations", .int(2))])
        watched.beginSpan("solve", attributes: [.of("annotations", .int(2))])
        _ = quiet.endSpan()
        _ = watched.endSpan()
        #expect(quiet.canonicalText == watched.canonicalText)
    }

    @Test("Emitting nothing is the default")
    func silentByDefault() {
        var trace = TraceLog(ticks: ManualTickSource())
        trace.beginSpan("solve")
        _ = trace.endSpan()
        #expect(!trace.canonicalText.isEmpty)
    }
}

@Suite("Performance budgets")
struct PerformanceBudgetTests {

    @Test("Every budget says what is checked instead of the clock")
    func everyBudgetNamesItsCounterpart() {
        for budget in PerformanceBudget.all {
            #expect(!budget.stage.isEmpty)
            #expect(budget.milliseconds > 0)
            #expect(!budget.checkedBy.isEmpty, Comment(rawValue: "\(budget.stage) names nothing"))
        }
    }

    @Test("No two budgets are about the same stage")
    func stagesAreDistinct() {
        let stages = PerformanceBudget.all.map(\.stage)
        #expect(Set(stages).count == stages.count)
    }

    @Test("Every budget is attached to a span name")
    func everyBudgetNamesASpan() {
        for budget in PerformanceBudget.all {
            #expect(!budget.signpost.isEmpty)
        }
    }
}
