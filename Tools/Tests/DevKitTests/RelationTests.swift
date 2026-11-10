@testable import DevKit
import Testing

@Suite("A relationship with no name")
struct RelationTests {
    private func findings(_ source: String) -> [Finding] {
        RelationRules.findings(in: source, path: "Sources/Whatever.swift")
    }

    @Test("Handing back two things at once without naming what they are together")
    func tupleReturn() {
        let found = findings("func f() -> (score: Double, rows: Int) { (0, 0) }")
        #expect(found.count == 1)
    }

    @Test("Handing back one thing is not a relationship")
    func single() {
        #expect(findings("func f() -> Double { 0 }").isEmpty)
    }

    @Test("A pair that may be absent is still a pair")
    func optionalTuple() {
        #expect(findings("func f() -> (a: Int, b: Int)? { nil }").count == 1)
    }

    @Test("A pair that may be thrown instead is still a pair")
    func throwingTuple() {
        #expect(findings("func f() throws -> (a: Int, b: Int) { (0, 0) }").count == 1)
    }

    @Test("Taking a pair is as unnamed as handing one back")
    func tupleParameter() {
        #expect(findings("public func f(_ pair: (a: Int, b: Int)) {}").count == 1)
    }

    @Test("A stored pair keeps the relationship unnamed for as long as it is kept")
    func storedTuple() {
        #expect(findings("public struct S { public var pair: (a: Int, b: Int) }").count == 1)
    }

    @Test("A closure that hands back a pair is counted once, where it is written")
    func closureReturn() {
        #expect(findings("public func f(next: () -> (a: Int, b: Int)) {}").count == 1)
    }

    @Test("A pair kept to itself inside one file is nobody else's to misread")
    func privatePair() {
        #expect(findings("private func f() -> (a: Int, b: Int) { (0, 0) }").isEmpty)
        #expect(findings("fileprivate func f() -> (a: Int, b: Int) { (0, 0) }").isEmpty)
    }

    @Test("A pair inside a body is working, not an agreement with anybody")
    func localPair() {
        #expect(
            findings(
                """
                private func f() {
                    var pair: (a: Int, b: Int) = (0, 0)
                    use(pair)
                }
                """
            ).isEmpty)
    }

    @Test("A pair in a private member of a public type is still private")
    func privateMember() {
        #expect(
            findings("public struct S { private var pair: (a: Int, b: Int) }").isEmpty)
    }

    @Test("Advice says to give the pair a name")
    func advice() {
        let found = findings("public func f() -> (a: Int, b: Int) { (0, 0) }")
        #expect(found.first?.advice.contains("give it a name") == true)
    }
}
