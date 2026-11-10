@testable import DevKit
import Testing


@Suite("Determinism rules")
struct DeterminismTests {

    private func findings(_ source: String) -> [Finding] {
        DeterminismRules.findings(in: source, path: "T.swift")
    }


    @Test("A call that makes a fresh identifier is caught")
    func catchesUUID() {
        #expect(findings("let a = UUID()").count == 1)
    }

    @Test("The same call split across lines is caught")
    func catchesSplitCall() {
        let found = findings(
            """
            let a =
                UUID
                .init()
            """)
        #expect(found.count == 1)
    }

    @Test("Reading the wall clock is caught", arguments: ["Date()", "Date.now"])
    func catchesTheClock(expression: String) {
        #expect(findings("let a = \(expression)").count == 1)
    }

    @Test("Ambient locale is caught", arguments: ["Locale.current", "TimeZone.current"])
    func catchesAmbientEnvironment(expression: String) {
        #expect(findings("let a = \(expression)").count == 1)
    }

    @Test(
        "Randomness without a generator is caught",
        arguments: [
            "values.shuffled()", "values.randomElement()",
        ])
    func catchesRandomness(expression: String) {
        #expect(findings("let a = \(expression)").count == 1)
    }

    @Test("Other floating-point widths are caught", arguments: ["Float80", "Float16"])
    func catchesOtherWidths(name: String) {
        #expect(findings("let a: \(name) = 0").count == 1)
    }

    @Test("A declared dictionary is caught")
    func catchesDictionaryDeclaration() {
        #expect(findings("let lookup: [String: Int] = [:]").count == 1)
    }

    @Test("A declared set is caught")
    func catchesSetDeclaration() {
        #expect(findings("let seen: Set<String> = []").count == 1)
    }


    @Test("Text inside a string literal is not code")
    func stringLiteralIsNotCode() {
        #expect(findings(#"let text = "a string containing UUID() and Date()""#).isEmpty)
    }

    @Test("A line comment is not code")
    func lineCommentIsNotCode() {
        #expect(findings("// UUID() and Date() and Set<String>").isEmpty)
    }

    @Test("A block comment is not code")
    func blockCommentIsNotCode() {
        #expect(findings("/* UUID() and Dictionary<String, Int> */").isEmpty)
    }

    @Test("A documentation comment is not code")
    func documentationIsNotCode() {
        #expect(findings("/// Uses UUID() elsewhere.\nlet a = 1").isEmpty)
    }

    @Test("A name that merely contains a forbidden one is left alone")
    func similarNamesAreLeftAlone() {
        #expect(findings("let a = MyUUIDFactory()").isEmpty)
        #expect(findings("let b = DateFormatterCache()").isEmpty)
    }

    @Test("A deterministic generator is not randomness")
    func seededRandomnessIsAllowed() {
        #expect(findings("let a = values.shuffled(using: &generator)").isEmpty)
    }


    @Test("A line that says why is allowed")
    func allowedLineIsSkipped() {
        #expect(findings("let lookup: [String: Int] = [:]  // determinism:allow keys sorted at use").isEmpty)
    }

    @Test("An allowance can sit on the line above, said explicitly")
    func allowanceOnTheLineAbove() {
        #expect(
            findings(
                """
                // determinism:allow:next keys sorted at use
                let lookup: [String: Int] = [:]
                """
            ).isEmpty)
    }

    @Test("An allowance without :next does not reach the line below")
    func allowanceDoesNotReachDown() {
        #expect(
            findings(
                """
                // determinism:allow about this line
                let lookup: [String: Int] = [:]
                """
            ).count == 1)
    }

    @Test("An allowance may sit above the documentation it shares a block with")
    func allowanceAboveDocumentation() {
        #expect(
            findings(
                """
                // determinism:allow:next keys sorted at use
                /// What this is for.
                let lookup: [String: Int] = [:]
                """
            ).isEmpty)
    }

    @Test("Or below it, wherever reads better")
    func allowanceBelowDocumentation() {
        #expect(
            findings(
                """
                /// What this is for.
                // determinism:allow:next keys sorted at use
                let lookup: [String: Int] = [:]
                """
            ).isEmpty)
    }

    @Test("An allowance separated by code does not reach")
    func allowanceStopsAtCode() {
        #expect(
            findings(
                """
                // determinism:allow:next keys sorted at use
                let unrelated = 1
                let lookup: [String: Int] = [:]
                """
            ).count == 1)
    }

    @Test("An allowance on the line above needs a reason too")
    func nextAllowanceNeedsAReason() {
        #expect(
            findings(
                """
                // determinism:allow:next
                let lookup: [String: Int] = [:]
                """
            ).count == 1)
    }

    @Test("An allowance with no reason is not an allowance")
    func allowanceNeedsAReason() {
        #expect(findings("let lookup: [String: Int] = [:]  // determinism:allow").count == 1)
    }

    @Test("A finding says where it is and what to do instead")
    func findingReads() throws {
        let found = try #require(findings("let a = UUID()").first)
        #expect(found.line == 1)
        #expect(found.path == "T.swift")
        #expect(found.advice.contains("StableID"))
    }

    @Test("Findings come back in the order they appear")
    func findingsAreOrdered() {
        let found = findings("let a = UUID()\nlet b = Date()")
        #expect(found.map(\.line) == [1, 2])
    }
}

@Suite("Where a keyed store may be declared")
struct KeyedStoreTests {

    private func findings(_ source: String, in path: String = "Example.swift") -> [Finding] {
        DeterminismRules.findings(in: source, path: path)
    }

    @Test("Anywhere else, declaring one is a finding")
    func elsewhere() {
        #expect(!findings("private var images: [String: Image] = [:]").isEmpty)
        #expect(!findings("let seen: Set<String> = []").isEmpty)
    }

    @Test("The type that makes them unnecessary may hold one")
    func theOnePlace() {
        #expect(
            findings(
                "private var pairs: [Key: Value]",
                in: "EkranbildoGeometry/Lookup.swift"
            ).isEmpty)
        #expect(
            findings(
                "private let names: Set<String>",
                in: "EkranbildoGeometry/Lookup.swift"
            ).isEmpty)
    }

    @Test("It is that file, not any file with that name somewhere in it")
    func notJustTheName() {
        #expect(
            !findings(
                "private var pairs: [Key: Value]",
                in: "Elsewhere/NotLookup.swift"
            ).isEmpty)
        #expect(
            !findings("private var pairs: [Key: Value]", in: "Lookup.swift.backup").isEmpty)
    }

    @Test("The one place is still held to every other rule")
    func stillHeldToTheRest() {
        #expect(
            !findings("let now = Date()", in: "EkranbildoGeometry/Lookup.swift").isEmpty)
    }
}
