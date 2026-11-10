@testable import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoTestKit
import Foundation
import Testing

@Suite("Scene semantics")
struct SceneSemanticsTests {

    @Test("A normalised box becomes a scene rectangle")
    func boxConversion() {
        let size = Size(width: 200, height: 100)
        let converted = NormalizedBox(x: 0.1, y: 0.2, width: 0.5, height: 0.3).inScene(of: size)
        #expect(converted.minX == 20)
        #expect(converted.raw.width == 100)
        #expect(converted.raw.height == 30)
        #expect(converted.minY == 50)
    }

    @Test("The whole image converts to the whole canvas")
    func fullBox() {
        let size = Size(width: 320, height: 240)
        let converted = NormalizedBox(x: 0, y: 0, width: 1, height: 1).inScene(of: size)
        #expect(converted.minX == 0)
        #expect(converted.minY == 0)
        #expect(converted.raw.width == 320)
        #expect(converted.raw.height == 240)
    }

    @Test("A box near the bottom lands near the bottom")
    func verticalOrientation() {
        let size = Size(width: 100, height: 100)
        let low = NormalizedBox(x: 0, y: 0.05, width: 1, height: 0.1).inScene(of: size)
        let high = NormalizedBox(x: 0, y: 0.85, width: 1, height: 0.1).inScene(of: size)
        #expect(low.minY > high.minY)
        #expect(approximatelyEqual(low.minY, 85, tolerance: 1e-9))
        #expect(approximatelyEqual(high.minY, 5, tolerance: 1e-9))
    }

    @Test("Saliency reads back what was put in")
    func saliencyLookup() {
        let map = SaliencyMap(columns: 2, rows: 2, values: [0, 0.25, 0.5, 1])
        #expect(map[column: 0, row: 0] == 0)
        #expect(map[column: 1, row: 1] == 1)
    }

    @Test("A point anywhere in the canvas maps onto a cell")
    func saliencyAtPoint() {
        let map = SaliencyMap(columns: 2, rows: 2, values: [0, 0.25, 0.5, 1])
        let canvas = SceneRect(x: 0, y: 0, width: 100, height: 100)
        #expect(map.value(at: ScenePoint(x: 1, y: 1), in: canvas) == 0)
        #expect(map.value(at: ScenePoint(x: 99, y: 99), in: canvas) == 1)
        #expect(map.value(at: ScenePoint(x: 99, y: 1), in: canvas) == 0.25)
        #expect(map.value(at: ScenePoint(x: 100, y: 100), in: canvas) == 1)
    }

    @Test("Outside the canvas is not salient")
    func saliencyOutside() {
        let map = SaliencyMap(columns: 2, rows: 2, values: [1, 1, 1, 1])
        let canvas = SceneRect(x: 0, y: 0, width: 100, height: 100)
        #expect(map.value(at: ScenePoint(x: -1, y: 50), in: canvas) == 0)
        #expect(map.value(at: ScenePoint(x: 50, y: 101), in: canvas) == 0)
    }

    @Test("An empty map is uniformly unsalient")
    func emptySaliency() {
        let canvas = SceneRect(x: 0, y: 0, width: 100, height: 100)
        #expect(SaliencyMap.empty.value(at: ScenePoint(x: 50, y: 50), in: canvas) == 0)
        #expect(SaliencyMap.empty.isEmpty)
    }

    @Test("A malformed map reads as empty rather than trapping")
    func malformedSaliency() {
        let map = SaliencyMap(columns: 4, rows: 4, values: [0.5])
        let canvas = SceneRect(x: 0, y: 0, width: 100, height: 100)
        #expect(!map.isWellFormed)
        #expect(map.value(at: ScenePoint(x: 50, y: 50), in: canvas) == 0)
    }

    @Test("Saliency encodes as one line per row")
    func saliencyEncoding() throws {
        let map = SaliencyMap(columns: 3, rows: 2, values: [0, 0.5, 1, 0.25, 0.125, 0.9])
        let encoded = try JSONEncoder().encode(map)
        let text = try #require(String(data: Data(encoded), encoding: .utf8))
        #expect(text.contains("0.000 0.500 1.000"))
        #expect(text.contains("0.250 0.125 0.900"))
    }

    @Test("Saliency round trips to the precision it is written at")
    func saliencyRoundTrip() throws {
        let map = SaliencyMap(columns: 2, rows: 1, values: [0.123_456_789, 0.987_654_321])
        let decoded = try roundTripped(map)
        #expect(decoded.columns == map.columns)
        #expect(decoded.rows == map.rows)
        #expect(decoded.values == [0.123, 0.988])
    }

    @Test("An empty map round trips as empty")
    func emptySaliencyRoundTrip() throws {
        #expect(try roundTripped(SaliencyMap.empty) == .empty)
    }

    @Test("A malformed encoding decodes to something well formed or to nothing")
    func malformedEncoding() throws {
        let json = #"{"columns":3,"rows":2,"rowValues":["0.0 1.0"]}"#
        let decoded = try JSONDecoder().decode(SaliencyMap.self, from: Data(json.utf8))
        #expect(!decoded.isWellFormed)
    }

    @Test("Semantics survive a round trip through JSON")
    func roundTrip() throws {
        let semantics = SceneSemantics(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 120),
            elements: [
                ScreenElement(
                    rect: SceneRect(x: 10, y: 10, width: 40, height: 20),
                    kind: .text,
                    text: "Save",
                    confidence: 0.87,
                    provenance: .textRecognition
                )
            ],
            saliency: SaliencyMap(columns: 2, rows: 1, values: [0.25, 0.75]),
            providerVersion: "region-1"
        )
        #expect(try isJSONRoundTrippable(semantics))
    }

    @Test("The version travels with the answer")
    func versionTravels() throws {
        let semantics = SceneSemantics(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            elements: [],
            saliency: .empty,
            providerVersion: "vision-3"
        )
        let decoded = try roundTripped(semantics)
        #expect(decoded.providerVersion == "vision-3")
    }

    @Test("Text elements keep what was read")
    func textContent() {
        let element = ScreenElement(
            rect: SceneRect(x: 0, y: 0, width: 10, height: 10),
            kind: .text,
            text: "Continue",
            confidence: 1,
            provenance: .textRecognition
        )
        #expect(element.text == "Continue")
        #expect(element.canonicalText.contains("Continue"))
    }

    @Test("An element without text says nothing about it")
    func withoutText() {
        let element = ScreenElement(
            rect: SceneRect(x: 0, y: 0, width: 10, height: 10),
            kind: .surface,
            confidence: 1,
            provenance: .regionAnalysis
        )
        #expect(element.text == nil)
        #expect(!element.canonicalText.contains("\"\""))
    }
}
