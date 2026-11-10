@testable import DevKit
import Testing

@Suite("An outcome is not a thing to drop")
struct OutcomeTests {
    private func findings(_ source: String) -> [Finding] {
        OutcomeRules.findings(in: source, path: "Sources/Whatever.swift")
    }

    @Test("Saying a success flag may be ignored is how a failure gets reported as a success")
    func discardableBool() {
        let found = findings(
            """
            @discardableResult
            func put(_ bytes: [UInt8]) -> Bool { true }
            """
        )
        #expect(found.count == 1)
        #expect(found.first?.line == 1)
    }

    @Test("A result that carries a failure is the same thing under another name")
    func discardableResult() {
        #expect(
            findings(
                """
                @discardableResult
                func write() -> Result<Int, Failure> { .success(0) }
                """
            ).count == 1)
    }

    @Test("A value somebody may not want is fine to drop")
    func discardableValue() {
        #expect(
            findings(
                """
                @discardableResult
                func store(_ image: ImageBuffer) -> ImageRef { ref }
                """
            ).isEmpty)
    }

    @Test("A success flag that must be looked at is fine")
    func plainBool() {
        #expect(findings("func start() -> Bool { true }").isEmpty)
    }

    @Test("An optional success flag hides a failure just as well")
    func optionalBool() {
        #expect(
            findings(
                """
                @discardableResult
                func start() -> Bool? { true }
                """
            ).count == 1)
    }

    @Test("Advice names the two ways out rather than only complaining")
    func advice() {
        let found = findings(
            """
            @discardableResult
            func put() -> Bool { true }
            """
        )
        #expect(found.first?.advice.contains("act on it") == true)
    }
}
