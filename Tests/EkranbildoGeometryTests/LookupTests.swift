@testable import EkranbildoGeometry
import Foundation
import Testing

@Suite("A lookup nothing can iterate")
struct LookupTests {

    private let ages = Lookup<String, Int>(["one": 1, "two": 2, "three": 3])

    @Test("What was put in comes back")
    func lookupWorks() {
        #expect(ages["two"] == 2)
    }

    @Test("What was never put in is not there")
    func missing() {
        #expect(ages["four"] == nil)
    }

    @Test("It says how many it holds")
    func counted() {
        #expect(ages.count == 3)
        #expect(!ages.isEmpty)
        #expect(Lookup<String, Int>().isEmpty)
    }

    @Test("Something can be put in and taken out again")
    func mutable() {
        var changed = ages
        changed["four"] = 4
        #expect(changed["four"] == 4)
        changed["four"] = nil
        #expect(changed["four"] == nil)
        #expect(changed.count == 3)
    }

    @Test("Two with the same pairs are the same lookup")
    func equality() {
        #expect(ages == Lookup<String, Int>(["three": 3, "two": 2, "one": 1]))
    }

    @Test("There is no way to walk it")
    func notASequence() {
        #expect(!((ages as Any) is any Sequence))
    }

    @Test("What it holds can be handed over deliberately, in a fixed order")
    func orderedDeliberately() {
        #expect(ages.sortedKeys == ["one", "three", "two"])
        #expect(ages.sortedPairs.map(\.value) == [1, 3, 2])
    }

    @Test("The order it hands things over in does not depend on how it was built")
    func orderDoesNotDependOnInsertion() {
        let built = Lookup<String, Int>(["three": 3, "one": 1, "two": 2])
        #expect(built.sortedKeys == ages.sortedKeys)
    }
}

@Suite("A set of names nothing can iterate")
struct NameSetTests {

    private let modules: NameSet = ["EkranbildoCore", "EkranbildoGeometry"]

    @Test("It says whether it holds a name")
    func contains() {
        #expect(modules.contains("EkranbildoCore"))
        #expect(!modules.contains("AppKit"))
    }

    @Test("It says how many names it holds")
    func counted() {
        #expect(modules.count == 2)
        #expect(NameSet().isEmpty)
    }

    @Test("A name written twice is one name")
    func duplicates() {
        #expect(NameSet(["a", "a", "b"]).count == 2)
    }

    @Test("Two with the same names are the same set")
    func equality() {
        #expect(modules == ["EkranbildoGeometry", "EkranbildoCore"])
    }

    @Test("There is no way to walk it")
    func notASequence() {
        #expect(!((modules as Any) is any Sequence))
    }

    @Test("Names can be handed over deliberately, in a fixed order")
    func sorted() {
        #expect(modules.sorted == ["EkranbildoCore", "EkranbildoGeometry"])
    }

    @Test("Adding a name gives a set with it in")
    func adding() {
        #expect(modules.adding("AppKit").contains("AppKit"))
        #expect(modules.adding("AppKit").count == 3)
    }
}

@Suite("A lookup that is written down")
struct LookupCodingTests {

    @Test("What was written comes back")
    func roundTrips() throws {
        let original = Lookup<String, Int>(["one": 1, "two": 2])
        let written = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Lookup<String, Int>.self, from: written) == original)
    }

    @Test("The same pairs are written as the same bytes, however they were built")
    func stableBytes() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let one = Lookup<String, Int>(["b": 2, "a": 1, "c": 3])
        let other = Lookup<String, Int>(["c": 3, "a": 1, "b": 2])
        #expect(try encoder.encode(one) == encoder.encode(other))
    }

    @Test("An empty one is written as an empty thing")
    func empty() throws {
        let written = try JSONEncoder().encode(Lookup<String, Int>())
        #expect(try JSONDecoder().decode(Lookup<String, Int>.self, from: written).isEmpty)
    }
}
