@testable import EkranbildoContracts
import EkranbildoTestKit
import Testing

@Suite("Shadows and corners")
struct ShadowTests {

    @Test("A rounded rectangle keeps its corners inside itself")
    func roundedRectStaysInside() throws {
        let rect = SceneRect(x: 10, y: 20, width: 100, height: 60)
        let path = Path.roundedRect(rect, radius: 12)
        let bounds = try #require(path.bounds)

        #expect(bounds.minX >= rect.minX)
        #expect(bounds.minY >= rect.minY)
        #expect(bounds.maxX <= rect.maxX)
        #expect(bounds.maxY <= rect.maxY)
    }

    @Test("A radius too large for the rectangle is brought down to fit")
    func radiusIsClamped() throws {
        let rect = SceneRect(x: 0, y: 0, width: 40, height: 20)
        let huge = try #require(Path.roundedRect(rect, radius: 500).bounds)
        let half = try #require(Path.roundedRect(rect, radius: 10).bounds)
        #expect(huge == half)
    }

    @Test("A radius of nothing gives a plain rectangle")
    func zeroRadius() {
        let rect = SceneRect(x: 5, y: 5, width: 30, height: 30)
        #expect(Path.roundedRect(rect, radius: 0) == Path.rect(rect))
    }

    @Test("A shadow survives a round trip")
    func roundTrip() throws {
        let command = DrawCommand.shadow(
            Path.roundedRect(SceneRect(x: 0, y: 0, width: 50, height: 40), radius: 8),
            Shadow(
                blur: 12,
                offset: ScenePoint(x: 0, y: 6),
                color: Color(red: 0, green: 0, blue: 0, alpha: 0.3)
            )
        )
        #expect(try isJSONRoundTrippable(command))
    }

    @Test("A shadow's bounds include where it falls")
    func shadowBounds() throws {
        let rect = SceneRect(x: 100, y: 100, width: 50, height: 40)
        let command = DrawCommand.shadow(
            Path.rect(rect),
            Shadow(
                blur: 10,
                offset: ScenePoint(x: 0, y: 8),
                color: Color(red: 0, green: 0, blue: 0, alpha: 0.3)
            )
        )
        let bounds = try #require(command.bounds)
        #expect(bounds.maxY >= rect.maxY + 8 + 10)
        #expect(bounds.minX <= rect.minX - 10)
    }

    @Test("An image remembers how round its corners are")
    func imageCorners() throws {
        let command = DrawCommand.image(
            ImageRef(contentHash: "shot", pixelWidth: 40, pixelHeight: 30),
            SceneRect(x: 0, y: 0, width: 40, height: 30),
            opacity: 1,
            cornerRadius: 6
        )
        #expect(try isJSONRoundTrippable(command))
        #expect(command.canonicalText.contains("corner"))
    }

    @Test("A shadow says what it is in the golden format")
    func shadowCanonicalText() {
        let command = DrawCommand.shadow(
            Path.rect(SceneRect(x: 0, y: 0, width: 10, height: 10)),
            Shadow(
                blur: 4,
                offset: ScenePoint(x: 1, y: 2),
                color: Color(red: 0, green: 0, blue: 0, alpha: 0.5)
            )
        )
        let text = command.canonicalText
        #expect(text.contains("shadow"))
        #expect(text.contains("blur"))
        #expect(text.contains("2.000"))
    }
}
