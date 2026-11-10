import EkranbildoObservability
import Testing

@Suite("Borrowed text")
struct BorrowedTextTests {

    @Test("Borrowed text reads as borrowed, not as the program's own")
    func borrowedReadsDifferently() {
        #expect(TraceValue.borrowed("hello").canonicalText != TraceValue.string("hello").canonicalText)
    }

    @Test("Synthesising replaces what was borrowed")
    func synthesisReplacesBorrowed() {
        let value = TraceValue.borrowed("the customer's window title")
        #expect(value.synthesised { _ in "xxxx" } == .borrowed("xxxx"))
    }

    @Test("Synthesising leaves the program's own words alone")
    func synthesisLeavesProgramTextAlone() {
        for value in [
            TraceValue.string("noFeasibleCandidate"),
            .int(3),
            .double(0.5),
            .bool(true),
        ] {
            #expect(value.synthesised { _ in "xxxx" } == value)
        }
    }

    @Test("A list is synthesised through to its elements")
    func synthesisReachesIntoLists() {
        let value = TraceValue.list([.string("keep"), .borrowed("replace")])
        #expect(value.synthesised { _ in "xxxx" } == .list([.string("keep"), .borrowed("xxxx")]))
    }

    @Test("What replaces it is decided by the caller, not here")
    func replacementComesFromTheCaller() {
        #expect(TraceValue.borrowed("abc").synthesised { "\($0.count)" } == .borrowed("3"))
    }
}

@Suite("A synthesised trace")
struct SynthesisedTraceTests {

    private func log() -> TraceLog<ManualTickSource> {
        var trace = TraceLog(ticks: ManualTickSource())
        trace.beginSpan("solve", attributes: [.of("annotations", .int(2))])
        trace.event(
            "placed",
            attributes: [
                .of("label", .borrowed("Quarterly revenue, confidential")),
                .of("reason", .string("noFeasibleCandidate")),
                .of("margin", .double(0.25)),
            ]
        )
        _ = trace.endSpan()
        trace.finish()
        return trace
    }

    @Test("None of the borrowed words survive")
    func borrowedWordsDoNotSurvive() {
        let text = log().synthesised { _ in "xxxx" }.canonicalText
        #expect(!text.contains("Quarterly"))
        #expect(!text.contains("confidential"))
    }

    @Test("Everything else does")
    func everythingElseSurvives() {
        let text = log().synthesised { _ in "xxxx" }.canonicalText
        #expect(text.contains("solve"))
        #expect(text.contains("placed"))
        #expect(text.contains("noFeasibleCandidate"))
        #expect(text.contains("0.25"))
    }

    @Test("It is the same trace, line for line")
    func theShapeIsUnchanged() {
        let before = log().canonicalText.split(separator: "\n").count
        let after = log().synthesised { _ in "xxxx" }.canonicalText.split(separator: "\n").count
        #expect(before == after)
    }

    @Test("Synthesising a trace with nothing borrowed changes nothing")
    func nothingBorrowedNothingChanged() {
        var trace = TraceLog(ticks: ManualTickSource())
        trace.event("done", attributes: [.of("count", .int(1))])
        trace.finish()
        #expect(trace.synthesised { _ in "xxxx" }.canonicalText == trace.canonicalText)
    }
}

@Suite("Synthesising a written trace")
struct WrittenTraceSynthesisTests {

    @Test("Borrowed text is replaced and the program's own is not")
    func replacesOnlyBorrowed() {
        let text = #"[0] placed label=~"Secret" reason="noFeasibleCandidate""#
        let synthesised = TraceSynthesis.applied(to: text)
        #expect(!synthesised.contains("Secret"))
        #expect(synthesised.contains("noFeasibleCandidate"))
    }

    @Test("The stand-in is as long as what it stands in for")
    func standInKeepsTheLength() {
        let synthesised = TraceSynthesis.applied(to: #"a=~"abcde""#)
        #expect(synthesised == #"a=~"xxxxx""#)
    }

    @Test("An escaped character counts once")
    func escapingDoesNotCount() {
        let synthesised = TraceSynthesis.applied(to: #"a=~"a\nb""#)
        #expect(synthesised == #"a=~"xxx""#)
    }

    @Test("A backslash before the closing quote does not hide it")
    func trailingBackslashDoesNotHideTheEnd() {
        let text = #"a=~"one\\" b="two""#
        let synthesised = TraceSynthesis.applied(to: text)
        #expect(!synthesised.contains("one"))
        #expect(synthesised.contains(#"b="two""#))
    }

    @Test("A quotation mark inside borrowed text does not end it early")
    func escapedQuoteDoesNotEndItEarly() {
        let synthesised = TraceSynthesis.applied(to: #"a=~"he said \"no\"" b="keep""#)
        #expect(!synthesised.contains("said"))
        #expect(synthesised.contains(#"b="keep""#))
    }

    @Test("An unterminated borrowed string is left alone")
    func unterminatedIsLeftAlone() {
        let text = #"a=~"never closed"#
        #expect(TraceSynthesis.applied(to: text) == text)
    }

    @Test("A trace with nothing borrowed comes back as it was")
    func nothingBorrowedNothingChanged() {
        let text = #"[0] solve annotations=2 reason="none""#
        #expect(TraceSynthesis.applied(to: text) == text)
    }

    @Test("What replaces it is the caller's to decide")
    func replacementIsTheCallers() {
        #expect(TraceSynthesis.applied(to: #"a=~"abc""#) { _ in "?" } == #"a=~"?""#)
    }
}

@Suite("Escaping comes back")
struct UnescapingTests {

    @Test(
        "Text survives being escaped and unescaped",
        arguments: [
            "plain",
            #"with "quotes""#,
            #"with \ backslash"#,
            "with\nnewline",
            "with\ttab",
            "\u{4FDD}\u{5B58}",
            "",
        ]
    )
    func roundTrips(text: String) {
        #expect(CanonicalText.unescaped(CanonicalText.escaped(text)) == text)
    }

    @Test("A trailing backslash that cannot have been escaped is kept")
    func trailingBackslashIsKept() {
        #expect(CanonicalText.unescaped(#"abc\"#) == #"abc\"#)
    }
}
