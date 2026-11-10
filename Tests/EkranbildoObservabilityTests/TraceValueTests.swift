@testable import EkranbildoObservability
import EkranbildoTestKit
import Testing

@Suite("TraceValue")
struct TraceValueTests {

    @Test("Values compare by case and payload")
    func equality() {
        #expect(areEquivalent(TraceValue.int(1), TraceValue.int(1)))
        #expect(TraceValue.int(1) != TraceValue.double(1))
        #expect(TraceValue.string("a") != TraceValue.string("b"))
    }

    @Test("Values render canonically so traces diff cleanly")
    func canonicalRendering() {
        #expect(TraceValue.string("hello").canonicalText == "\"hello\"")
        #expect(TraceValue.int(-42).canonicalText == "-42")
        #expect(TraceValue.bool(true).canonicalText == "true")
        #expect(TraceValue.list([.int(1), .int(2)]).canonicalText == "[1, 2]")
    }

    @Test("Doubles render without platform-dependent noise")
    func doubleRendering() {
        #expect(TraceValue.double(0.5).canonicalText == "0.5")
        #expect(TraceValue.double(1).canonicalText == "1.0")
        #expect(TraceValue.double(-0.0).canonicalText == "0.0")
        #expect((-0.0 as Double).sign == .minus)
        #expect(TraceValue.double(.infinity).canonicalText == "inf")
        #expect(TraceValue.double(-.infinity).canonicalText == "-inf")
        #expect(TraceValue.double(.nan).canonicalText == "nan")
    }

    @Test("Strings are escaped so that a value can never break the trace format")
    func stringEscaping() {
        #expect(TraceValue.string("a\"b").canonicalText == "\"a\\\"b\"")
        #expect(TraceValue.string("a\\b").canonicalText == "\"a\\\\b\"")
        #expect(TraceValue.string("a\nb").canonicalText == "\"a\\nb\"")
        #expect(TraceValue.string("a\tb").canonicalText == "\"a\\tb\"")
    }
}

@Suite("TraceAttributes")
struct TraceAttributesTests {

    @Test("Attributes are ordered by key regardless of insertion order")
    func canonicalOrdering() {
        let forwards = TraceAttributes([.of("alpha", .int(1)), .of("beta", .int(2)), .of("gamma", .int(3))])
        let backwards = TraceAttributes([.of("gamma", .int(3)), .of("beta", .int(2)), .of("alpha", .int(1))])
        #expect(forwards == backwards)
        #expect(forwards.keys == ["alpha", "beta", "gamma"])
        #expect(forwards.canonicalText == backwards.canonicalText)
    }

    @Test("A later value for the same key replaces the earlier one")
    func duplicateKeysResolveToTheLastValue() {
        let attributes = TraceAttributes([.of("k", .int(1)), .of("k", .int(2))])
        #expect(attributes.keys == ["k"])
        #expect(attributes["k"] == .int(2))
    }

    @Test("Lookups return nil for absent keys")
    func lookup() {
        let attributes = TraceAttributes([.of("present", .bool(true))])
        #expect(attributes["present"] == .bool(true))
        #expect(attributes["absent"] == nil)
    }

    @Test("An empty attribute set renders as empty")
    func empty() {
        #expect(TraceAttributes([]).isEmpty)
        #expect(TraceAttributes([]).canonicalText.isEmpty)
    }

    @Test("Attributes render as sorted key-value pairs")
    func rendering() {
        let attributes = TraceAttributes([.of("b", .int(2)), .of("a", .string("x"))])
        #expect(attributes.canonicalText == "a=\"x\" b=2")
    }

    @Test("Merging prefers the values of the overriding set")
    func merging() {
        let base = TraceAttributes([.of("a", .int(1)), .of("b", .int(2))])
        let overrides = TraceAttributes([.of("b", .int(20)), .of("c", .int(3))])
        let merged = base.merging(overrides)
        #expect(merged.keys == ["a", "b", "c"])
        #expect(merged["b"] == .int(20))
    }
}
