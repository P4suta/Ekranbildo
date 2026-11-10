@testable import EkranbildoCLI
import Testing

@Suite("Flag scanner")
struct FlagScannerTests {

    private static let known = ["--out", "--scale"]

    private func scan(_ arguments: [String]) throws -> FlagScanner {
        try FlagScanner.scan(arguments, knownFlags: Self.known)
    }

    @Test("Positionals and flags are told apart")
    func splits() throws {
        let parsed = try scan(["scene.json", "--out", "picture.png"])
        #expect(parsed.positional == ["scene.json"])
        #expect(parsed.value(of: "--out") == "picture.png")
    }

    @Test("Repeating a flag overrides rather than being ignored")
    func lastWins() throws {
        let parsed = try scan(["scene.json", "--out", "first.png", "--out", "second.png"])
        #expect(parsed.value(of: "--out") == "second.png")
    }

    @Test("A flag nobody asked for is refused rather than ignored")
    func unknownFlag() {
        #expect(throws: CommandError.self) { try self.scan(["a", "--nope", "x"]) }
    }

    @Test("A flag without a value is refused")
    func missingValue() {
        #expect(throws: CommandError.self) { try self.scan(["a", "--out"]) }
    }

    @Test("A flag that was never given has no value")
    func absentFlag() throws {
        #expect(try scan(["a"]).value(of: "--out") == nil)
    }

    @Test("Positionals keep the order they were given in")
    func positionalOrder() throws {
        let parsed = try scan(["one", "--out", "x", "two", "three"])
        #expect(parsed.positional == ["one", "two", "three"])
    }

    @Test("A value is taken as given, even when it looks like a flag")
    func valueLikeAFlag() throws {
        #expect(try scan(["a", "--out", "--scale"]).value(of: "--out") == "--scale")
    }
}
