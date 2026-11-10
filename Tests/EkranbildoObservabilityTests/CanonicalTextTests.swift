@testable import EkranbildoObservability
import Testing

@Suite("CanonicalText")
struct CanonicalTextTests {

    @Test("Rounding produces a fixed number of decimal places")
    func roundingPlaces() {
        #expect(CanonicalText.rounded(1.23456, places: 3) == "1.235")
        #expect(CanonicalText.rounded(1, places: 3) == "1.000")
        #expect(CanonicalText.rounded(0.5, places: 0) == "1")
        #expect(CanonicalText.rounded(12.0, places: 2) == "12.00")
    }

    @Test("Rounding keeps the sign and normalises negative zero")
    func roundingSigns() {
        #expect(CanonicalText.rounded(-1.5, places: 1) == "-1.5")
        #expect(CanonicalText.rounded(-0.0001, places: 2) == "0.00")
        #expect(CanonicalText.rounded(-0.006, places: 2) == "-0.01")
    }

    @Test("Values differing below the rounding threshold render identically")
    func roundingAbsorbsUlpNoise() {
        let base = 0.1 + 0.2
        #expect(CanonicalText.double(base) != CanonicalText.double(0.3))
        #expect(CanonicalText.rounded(base, places: 3) == CanonicalText.rounded(0.3, places: 3))
    }

    @Test("Non-finite values render as words")
    func nonFinite() {
        #expect(CanonicalText.rounded(.nan, places: 2) == "nan")
        #expect(CanonicalText.rounded(.infinity, places: 2) == "inf")
        #expect(CanonicalText.rounded(-.infinity, places: 2) == "-inf")
    }

    @Test("Quoting escapes the characters that would break the format")
    func quoting() {
        #expect(CanonicalText.quoted("a\"b") == "\"a\\\"b\"")
        #expect(CanonicalText.quoted("line\nbreak") == "\"line\\nbreak\"")
    }
}
