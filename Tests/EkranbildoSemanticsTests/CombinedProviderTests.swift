import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoSemantics
import EkranbildoTestKit
import Testing

@Suite("Combined provider")
struct CombinedProviderTests {

    private struct StatedProvider: SemanticProvider {
        let version: String
        let elements: [ScreenElement]
        var saliency: SaliencyMap = .empty

        func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
            SceneSemantics(
                canvas: SceneRect(
                    x: 0, y: 0, width: Double(image.width), height: Double(image.height)),
                elements: elements,
                saliency: saliency,
                providerVersion: version
            )
        }
    }

    private func element(
        _ rect: SceneRect,
        kind: ScreenElement.Kind,
        provenance: ScreenElement.Provenance
    ) -> ScreenElement {
        ScreenElement(rect: rect, kind: kind, confidence: 1, provenance: provenance)
    }

    private var image: ImageBuffer { SceneLibrary.applicationWindow.image }

    @Test("Findings from every detector come through")
    func mergesFindings() throws {
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "a",
                elements: [
                    element(
                        SceneRect(x: 0, y: 0, width: 200, height: 80),
                        kind: .surface,
                        provenance: .regionAnalysis
                    )
                ]
            ),
            StatedProvider(
                version: "b",
                elements: [
                    element(
                        SceneRect(x: 10, y: 10, width: 100, height: 20),
                        kind: .text,
                        provenance: .textRecognition
                    )
                ]
            ),
        ])
        let answer = try combined.analyse(image)
        #expect(answer.elements.count == 2)
        #expect(answer.providerVersion == "a+b")
    }

    @Test("Region fragments inside recognised text are dropped")
    func dropsGlyphFragments() throws {
        let line = SceneRect(x: 100, y: 100, width: 300, height: 24)
        let glyphs = [
            SceneRect(x: 104, y: 104, width: 12, height: 16),
            SceneRect(x: 120, y: 104, width: 10, height: 16),
            SceneRect(x: 136, y: 105, width: 11, height: 15),
        ]
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "regions",
                elements: glyphs.map { element($0, kind: .surface, provenance: .regionAnalysis) }
            ),
            StatedProvider(
                version: "text",
                elements: [element(line, kind: .text, provenance: .textRecognition)]
            ),
        ])
        let answer = try combined.analyse(image)
        #expect(answer.elements.count == 1)
        #expect(answer.elements.first?.kind == .text)
    }

    @Test("A surface containing recognised text is kept")
    func keepsContainingSurfaces() throws {
        let button = SceneRect(x: 90, y: 90, width: 160, height: 40)
        let label = SceneRect(x: 110, y: 100, width: 100, height: 20)
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "regions",
                elements: [element(button, kind: .surface, provenance: .regionAnalysis)]
            ),
            StatedProvider(
                version: "text",
                elements: [element(label, kind: .text, provenance: .textRecognition)]
            ),
        ])
        let answer = try combined.analyse(image)
        #expect(answer.elements.count == 2)
        #expect(answer.elements.first?.rect == button, "the coarser reading comes first")
    }

    @Test("A surface exactly coincident with a line of text is one finding")
    func coincidentFindings() throws {
        let box = SceneRect(x: 100, y: 100, width: 120, height: 24)
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "regions",
                elements: [element(box, kind: .surface, provenance: .regionAnalysis)]
            ),
            StatedProvider(
                version: "text",
                elements: [element(box, kind: .text, provenance: .textRecognition)]
            ),
        ])
        let answer = try combined.analyse(image)
        #expect(answer.elements.count == 1)
        #expect(answer.elements.first?.kind == .text)
    }

    @Test("A region that only overlaps text is kept")
    func keepsOverlappingRegions() throws {
        let line = SceneRect(x: 100, y: 100, width: 300, height: 24)
        let rule = SceneRect(x: 0, y: 110, width: 800, height: 10)
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "regions",
                elements: [element(rule, kind: .surface, provenance: .regionAnalysis)]
            ),
            StatedProvider(
                version: "text",
                elements: [element(line, kind: .text, provenance: .textRecognition)]
            ),
        ])
        #expect(try combined.analyse(image).elements.count == 2)
    }

    @Test("Text is never dropped for sitting inside other text")
    func textIsNeverDropped() throws {
        let outer = SceneRect(x: 0, y: 0, width: 400, height: 100)
        let inner = SceneRect(x: 10, y: 10, width: 80, height: 20)
        let combined = CombinedSemanticProvider([
            StatedProvider(
                version: "text",
                elements: [
                    element(outer, kind: .text, provenance: .textRecognition),
                    element(inner, kind: .text, provenance: .textRecognition),
                ]
            )
        ])
        #expect(try combined.analyse(image).elements.count == 2)
    }

    @Test("The first detector with an opinion about saliency keeps it")
    func firstSaliencyWins() throws {
        let first = SaliencyMap(columns: 2, rows: 1, values: [1, 0])
        let second = SaliencyMap(columns: 2, rows: 1, values: [0, 1])
        let combined = CombinedSemanticProvider([
            StatedProvider(version: "a", elements: [], saliency: first),
            StatedProvider(version: "b", elements: [], saliency: second),
        ])
        #expect(try combined.analyse(image).saliency == first)
    }

    @Test("A detector without saliency does not block the next")
    func laterSaliencyIsUsed() throws {
        let later = SaliencyMap(columns: 2, rows: 1, values: [0.25, 0.75])
        let combined = CombinedSemanticProvider([
            StatedProvider(version: "a", elements: []),
            StatedProvider(version: "b", elements: [], saliency: later),
        ])
        #expect(try combined.analyse(image).saliency == later)
    }

    @Test("With one detector the answer is that detector's")
    func singleProvider() throws {
        let only = element(
            SceneRect(x: 0, y: 0, width: 10, height: 10),
            kind: .surface,
            provenance: .regionAnalysis
        )
        let combined = CombinedSemanticProvider([
            StatedProvider(version: "only", elements: [only])
        ])
        #expect(try combined.analyse(image).elements == [only])
    }

    @Test("Merging is reproducible")
    func reproducible() {
        let combined = CombinedSemanticProvider([
            RegionSemanticProvider(),
            StatedProvider(
                version: "text",
                elements: [
                    element(
                        SceneRect(x: 100, y: 60, width: 120, height: 20),
                        kind: .text,
                        provenance: .textRecognition
                    )
                ]
            ),
        ])
        let picture = image
        #expect(isReproducible { try? combined.analyse(picture) })
    }
}
