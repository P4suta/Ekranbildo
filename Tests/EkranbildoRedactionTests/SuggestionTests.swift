import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoRedaction
import EkranbildoTestKit
import Testing

@Suite("Suggesting masks")
struct SuggestionTests {

    private func line(_ text: String, _ rect: SceneRect) -> ScreenElement {
        ScreenElement(
            rect: rect,
            kind: .text,
            text: text,
            confidence: 1,
            provenance: .textRecognition
        )
    }

    @Test("A line containing a secret is suggested")
    func suggests() {
        let found = MaskSuggester().masks(
            in: [line("Contact alice@example.org", SceneRect(x: 10, y: 20, width: 200, height: 16))]
        )
        #expect(found.count == 1)
    }

    @Test("Only the part of the line that is the secret is covered")
    func coversPartOfTheLine() throws {
        let whole = SceneRect(x: 0, y: 20, width: 250, height: 16)
        let suggested = try #require(
            MaskSuggester().masks(in: [line("Contact alice@example.org", whole)]).first
        )
        #expect(suggested.rect.raw.width < whole.raw.width)
        #expect(suggested.rect.minX > whole.minX)
        #expect(suggested.rect.maxX <= whole.maxX + Tolerances.edge)
    }

    @Test("A mask reaches a little past the text it covers")
    func coversGenerously() throws {
        let whole = SceneRect(x: 0, y: 20, width: 170, height: 16)
        let suggested = try #require(
            MaskSuggester().masks(in: [line("alice@example.org", whole)]).first
        )
        #expect(suggested.rect.minY < whole.minY)
        #expect(suggested.rect.maxY > whole.maxY)
    }

    @Test("A line with nothing in it suggests nothing")
    func nothingToSuggest() {
        #expect(
            MaskSuggester().masks(
                in: [line("Deployment target", SceneRect(x: 0, y: 0, width: 100, height: 16))]
            ).isEmpty
        )
    }

    @Test("An element that is not text is skipped")
    func skipsNonText() {
        let surface = ScreenElement(
            rect: SceneRect(x: 0, y: 0, width: 100, height: 40),
            kind: .surface,
            confidence: 1,
            provenance: .regionAnalysis
        )
        #expect(MaskSuggester().masks(in: [surface]).isEmpty)
    }

    @Test("Two secrets in one line get two masks")
    func twoInALine() {
        let found = MaskSuggester().masks(
            in: [
                line(
                    "alice@example.org and bob@example.org",
                    SceneRect(x: 0, y: 0, width: 300, height: 16)
                )
            ]
        )
        #expect(found.count == 2)
        #expect(found[0].rect.minX < found[1].rect.minX)
    }

    @Test("A suggested mask is one that leaves nothing behind")
    func irreversibleByDefault() {
        let found = MaskSuggester().masks(
            in: [line("alice@example.org", SceneRect(x: 0, y: 0, width: 170, height: 16))]
        )
        #expect(found.allSatisfy { $0.style.isIrreversible })
    }

    @Test("Suggesting is reproducible")
    func reproducible() {
        let elements = [
            line("alice@example.org", SceneRect(x: 0, y: 0, width: 170, height: 16)),
            line("10.0.0.1", SceneRect(x: 0, y: 30, width: 80, height: 16)),
        ]
        #expect(isReproducible { MaskSuggester().masks(in: elements) })
    }

    private enum Tolerances {
        static let edge: Double = 8
    }
}
