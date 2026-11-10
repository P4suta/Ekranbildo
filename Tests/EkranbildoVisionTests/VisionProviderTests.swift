import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoRenderCoreGraphics
import EkranbildoTestKit
@testable import EkranbildoVision
import Testing

@Suite("Vision provider")
struct VisionProviderTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 420, height: 200)

    private func rendered(_ words: [(String, ScenePoint)]) throws -> ImageBuffer {
        let measurer = TabulatedTextMeasurer.uniform()
        let font = FontSpec(family: "Helvetica", size: 36, weight: .bold)
        var commands: [DrawCommand] = [
            .fill(.rect(Self.canvas), .solid(Color(red: 1, green: 1, blue: 1, alpha: 1)))
        ]
        for (word, origin) in words {
            commands.append(
                .text(
                    TextRun(
                        text: word,
                        font: font,
                        baselineOrigin: origin,
                        paint: .solid(Color(red: 0, green: 0, blue: 0, alpha: 1)),
                        metrics: measurer.measure(word, font: font)
                    )
                )
            )
        }
        let list = DrawList(canvas: Self.canvas, colorSpace: .sRGB, commands: commands)
        let result = try CoreGraphicsRenderer().render(list, scale: Self.scale)
        return try ImageCodec.decode(try result.bitmap.pngData()).image
    }

    private static let scale = 2.0

    @Test("Words drawn on the canvas are read back")
    func readsText() throws {
        let image = try rendered([("Settings", ScenePoint(x: 30, y: 70))])
        let semantics = try VisionSemanticProvider(findsSaliency: false).analyse(image)

        let words = semantics.elements.compactMap(\.text).joined(separator: " ")
        #expect(words.contains("Settings"), "read back: '\(words)'")
        #expect(semantics.elements.allSatisfy { $0.kind == .text })
        #expect(semantics.elements.allSatisfy { $0.provenance == .textRecognition })
    }

    @Test("A word is found where it was drawn")
    func positionsAgree() throws {
        let baseline = ScenePoint(x: 30, y: 70)
        let image = try rendered([("Settings", baseline)])
        let semantics = try VisionSemanticProvider(findsSaliency: false).analyse(image)

        let found = try #require(semantics.elements.first { $0.text?.contains("Settings") == true })
        let scale = Self.scale
        #expect(abs(found.rect.minX - baseline.x * scale) < Tolerances.position)
        #expect(found.rect.minY < baseline.y * scale)
        #expect(found.rect.maxY > baseline.y * scale)
    }

    @Test("Two lines come back in reading order")
    func readingOrder() throws {
        let image = try rendered([
            ("Alpha", ScenePoint(x: 30, y: 60)),
            ("Bravo", ScenePoint(x: 30, y: 140)),
        ])
        let semantics = try VisionSemanticProvider(findsSaliency: false).analyse(image)
        let words = semantics.elements.compactMap(\.text)

        let alpha = try #require(words.firstIndex { $0.contains("Alpha") })
        let bravo = try #require(words.firstIndex { $0.contains("Bravo") })
        #expect(alpha < bravo, "read back: \(words)")
    }

    @Test("A picture with no words produces no text")
    func blankImage() throws {
        let image = try rendered([])
        #expect(try VisionSemanticProvider(findsSaliency: false).analyse(image).elements.isEmpty)
    }

    @Test("The answer describes the picture it was asked about")
    func canvasTravels() throws {
        let image = try rendered([("Settings", ScenePoint(x: 30, y: 70))])
        let semantics = try VisionSemanticProvider(findsSaliency: false).analyse(image)
        #expect(semantics.canvas.raw.width == Double(image.width))
        #expect(semantics.canvas.raw.height == Double(image.height))
    }

    @Test("The pinned revision is part of the version")
    func versionNamesTheRevision() {
        let version = VisionSemanticProvider().version
        #expect(version.contains("\(VisionSemanticProvider.Revisions.text)"))
        #expect(version.contains("\(VisionSemanticProvider.Revisions.saliency)"))
    }

    @Test("Saliency comes back shaped and in range")
    func saliency() throws {
        let image = try rendered([("Settings", ScenePoint(x: 30, y: 70))])
        let map = try VisionSemanticProvider(recognizesText: false).analyse(image).saliency
        #expect(map.isWellFormed)
        #expect(map.values.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test("Either half of the work can be turned off")
    func selectable() throws {
        let image = try rendered([("Settings", ScenePoint(x: 30, y: 70))])
        #expect(try VisionSemanticProvider(findsSaliency: false).analyse(image).saliency.isEmpty)
        #expect(try VisionSemanticProvider(recognizesText: false).analyse(image).elements.isEmpty)
    }

    @Test("A reading is reproducible within a run")
    func reproducible() throws {
        let image = try rendered([("Settings", ScenePoint(x: 30, y: 70))])
        let provider = VisionSemanticProvider(findsSaliency: false)
        #expect(isReproducible { try? provider.analyse(image) })
    }

    private enum Tolerances {
        static let position: Double = 40
    }
}
