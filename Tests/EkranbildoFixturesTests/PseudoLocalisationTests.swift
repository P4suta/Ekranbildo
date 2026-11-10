@testable import EkranbildoFixtures
import EkranbildoTestKit
import Testing

@Suite("Pseudo-localisation")
struct PseudoLocalisationTests {

    private enum Brackets {
        static let count = 2
    }

    @Test("A label comes out longer than it went in")
    func expands() {
        let short = PseudoLocalisation.of("Save")
        #expect(short.count > "Save".count)
    }

    @Test(
        "A label expands by the allowance a translation needs",
        arguments: ["OK", "Save", "Open the settings panel"]
    )
    func expandsByTheAllowance(text: String) {
        let grown = PseudoLocalisation.of(text).count - Brackets.count
        #expect(Double(grown) >= Double(text.count) * 1.4)
    }

    @Test("A very short label expands by more than its share", arguments: ["", "I", "OK", "Go"])
    func shortLabelsExpandByMore(text: String) {
        guard !text.isEmpty else {
            #expect(PseudoLocalisation.of(text).isEmpty)
            return
        }
        let grown = PseudoLocalisation.of(text).count - Brackets.count
        #expect(grown >= text.count + 3)
    }

    @Test("The letters are not the ones that went in")
    func accents() {
        let transformed = PseudoLocalisation.of("Save")
        #expect(!transformed.contains("S"))
        #expect(!transformed.contains("a"))
        #expect(transformed.unicodeScalars.contains { $0.value > 127 })
    }

    @Test("A label is bracketed so that anything cut off is obvious")
    func bracketed() {
        let transformed = PseudoLocalisation.of("Save")
        #expect(transformed.hasPrefix("["))
        #expect(transformed.hasSuffix("]"))
    }

    @Test("Letters that are not English are left as they are")
    func leavesOtherAlphabets() {
        #expect(PseudoLocalisation.of("保存").contains("保存"))
        #expect(
            PseudoLocalisation.of("\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}").contains(
                "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"))
    }

    @Test("Nothing in gives nothing out rather than a pair of brackets")
    func empty() {
        #expect(PseudoLocalisation.of("").isEmpty)
    }

    @Test("Spacing and punctuation survive")
    func keepsShape() {
        let transformed = PseudoLocalisation.of("Save as...")
        #expect(transformed.contains(" "))
        #expect(transformed.contains("..."))
    }

    @Test("The same label always comes out the same")
    func reproducible() {
        #expect(isReproducible { PseudoLocalisation.of("Save as...") })
    }

    @Test("Two different labels stay different")
    func distinct() {
        #expect(PseudoLocalisation.of("Save") != PseudoLocalisation.of("Open"))
    }
}
