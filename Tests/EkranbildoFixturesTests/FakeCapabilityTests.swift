import EkranbildoContracts
@testable import EkranbildoFixtures
import Testing

@Suite("TabulatedTextMeasurer")
struct TabulatedTextMeasurerTests {
    private let font = FontSpec(family: "Inter", size: 16, weight: .regular)

    @Test("An empty string has no width but keeps the font's vertical metrics")
    func emptyString() {
        let measurer = TabulatedTextMeasurer.uniform()
        let metrics = measurer.measure("", font: font)
        #expect(metrics.width == 0)
        #expect(metrics.ascent > 0)
        #expect(metrics.descent > 0)
    }

    @Test("Width grows with the number of characters")
    func widthScalesWithLength() {
        let measurer = TabulatedTextMeasurer.uniform()
        let one = measurer.measure("a", font: font).width
        let three = measurer.measure("aaa", font: font).width
        #expect(approximatelyEqualWidths(three, one * 3))
    }

    @Test("Width scales with the font size")
    func widthScalesWithSize() {
        let measurer = TabulatedTextMeasurer.uniform()
        let small = measurer.measure("hello", font: FontSpec(family: "Inter", size: 10)).width
        let large = measurer.measure("hello", font: FontSpec(family: "Inter", size: 20)).width
        #expect(approximatelyEqualWidths(large, small * 2))
    }

    @Test("Measurement is reproducible")
    func reproducible() {
        let first = TabulatedTextMeasurer.uniform()
        let second = TabulatedTextMeasurer.uniform()
        for sample in ["", "a", "Hello, world", "日本語のラベル", "🎯 emoji", "\u{0301}combining"] {
            #expect(first.measure(sample, font: font) == second.measure(sample, font: font))
        }
    }

    @Test("Wide characters measure wider than narrow ones")
    func wideCharacters() {
        let measurer = TabulatedTextMeasurer.uniform()
        let latin = measurer.measure("ab", font: font).width
        let cjk = measurer.measure("日本", font: font).width
        #expect(cjk > latin)
    }

    @Test("A specific advance can be tabulated for a character")
    func tabulatedOverrides() {
        let measurer = TabulatedTextMeasurer(
            defaultAdvanceRatio: 0.5,
            wideAdvanceRatio: 1.0,
            ascentRatio: 0.8,
            descentRatio: 0.2,
            advances: [Advance("i", 0.25)]
        )
        let narrow = measurer.measure("i", font: font).width
        let normal = measurer.measure("n", font: font).width
        #expect(narrow == 0.25 * 16)
        #expect(normal == 0.5 * 16)
    }

    private func approximatelyEqualWidths(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 1e-9
    }
}

@Suite("ManualClock")
struct ManualClockTests {

    @Test("The clock reports exactly what it was set to")
    func fixedTime() {
        let clock = ManualClock(now: 1_700_000_000)
        #expect(clock.now() == 1_700_000_000)
        #expect(clock.now() == 1_700_000_000)
    }

    @Test("The clock can be moved forward")
    func advancing() {
        let clock = ManualClock(now: 100)
        clock.advance(by: 30)
        #expect(clock.now() == 130)
    }
}

@Suite("InMemoryFileStore")
struct InMemoryFileStoreTests {

    @Test("Stored bytes can be read back")
    func roundTrip() throws {
        let store = InMemoryFileStore()
        let handle = try store.store([1, 2, 3], as: "out.png")
        #expect(handle.byteCount == 3)
        #expect(try store.load(handle) == [1, 2, 3])
    }

    @Test("Storing the same name twice replaces the contents")
    func overwrite() throws {
        let store = InMemoryFileStore()
        _ = try store.store([1], as: "a")
        let second = try store.store([9, 9], as: "a")
        #expect(try store.load(second) == [9, 9])
        #expect(store.names == ["a"])
    }

    @Test("Names are reported in sorted order rather than hash order")
    func sortedNames() throws {
        let store = InMemoryFileStore()
        for name in ["zebra", "apple", "mango"] {
            _ = try store.store([0], as: name)
        }
        #expect(store.names == ["apple", "mango", "zebra"])
    }

    @Test("Loading an unknown file reports a diagnostic code")
    func missingFile() {
        let store = InMemoryFileStore()
        let unknown = StoredFile(identifier: "nope", byteCount: 0)
        #expect(throws: CapabilityError.self) {
            try store.load(unknown)
        }
    }
}

@Suite("Fixture capability bundle")
struct FixtureCapabilitiesTests {

    @Test("The standard bundle wires up deterministic implementations")
    func standardBundle() {
        let capabilities = Capabilities.fixture()
        #expect(capabilities.clock.now() == FixtureDefaults.clockTime)
        let metrics = capabilities.text.measure("ab", font: FontSpec(family: "Inter", size: 10))
        #expect(metrics.width > 0)
    }
}
