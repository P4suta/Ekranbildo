@testable import DevKit
import Testing


@Suite("Snippets")
struct SnippetTests {

    @Test("A snippet that compiled when it had to is right")
    func requiredSuccessThatCompiles() {
        let snippet = Snippet(name: "x", expectation: .compiles, source: "")
        #expect(snippet.verdict(compiled: true) == .asExpected)
    }

    @Test("A snippet that did not compile when it had to is wrong")
    func requiredSuccessThatFailed() {
        let snippet = Snippet(name: "x", expectation: .compiles, source: "")
        #expect(snippet.verdict(compiled: false) == .unexpected)
    }

    @Test("A snippet that failed when it had to is right")
    func requiredFailureThatFailed() {
        let snippet = Snippet(name: "x", expectation: .isRejected, source: "")
        #expect(snippet.verdict(compiled: false) == .asExpected)
    }

    @Test("A snippet that compiled when it had to fail is wrong")
    func requiredFailureThatCompiled() {
        let snippet = Snippet(name: "x", expectation: .isRejected, source: "")
        #expect(snippet.verdict(compiled: true) == .unexpected)
    }


    @Test("There is a snippet that has to compile")
    func thereIsABaseline() {
        #expect(Snippets.all.contains { $0.expectation == .compiles })
    }

    @Test("The baseline comes first, so nothing after it means anything without it")
    func theBaselineComesFirst() throws {
        let first = try #require(Snippets.all.first)
        #expect(first.expectation == .compiles)
    }

    @Test("Every snippet says what rule it is about")
    func everySnippetIsNamed() {
        #expect(Snippets.all.allSatisfy { !$0.name.isEmpty && !$0.source.isEmpty })
    }

    @Test("No two snippets share a name")
    func namesAreDistinct() {
        let names = Snippets.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("Most of them are rules, not baselines")
    func mostAreRules() {
        let rules = Snippets.all.filter { $0.expectation == .isRejected }
        #expect(rules.count >= 4)
    }
}
