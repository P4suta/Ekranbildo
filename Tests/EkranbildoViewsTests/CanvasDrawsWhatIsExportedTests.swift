import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoRender
import EkranbildoRenderCoreGraphics
@testable import EkranbildoViews
import Testing

@Suite("The canvas draws what is exported", .serialized)
@MainActor
struct CanvasDrawsWhatIsExportedTests {

    private static let scene = SceneLibrary.sampleAnnotated

    private func canvasPixels(of scene: Scene) throws -> ImageBuffer {
        let view = CanvasView(scene: scene)
        view.frame = NSRect(
            x: 0, y: 0, width: scene.canvas.width, height: scene.canvas.height)
        view.layoutSubtreeIfNeeded()

        let representation = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(scene.canvas.width),
                pixelsHigh: Int(scene.canvas.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        representation.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: representation)

        let width = representation.pixelsWide
        let height = representation.pixelsHigh
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let colour = representation.colorAt(x: x, y: y) ?? .clear
                for channel in [
                    colour.redComponent, colour.greenComponent,
                    colour.blueComponent, colour.alphaComponent,
                ] {
                    pixels.append(UInt8(max(0, min(255, channel * 255)).rounded()))
                }
            }
        }
        return ImageBuffer(
            width: width, height: height, colorSpace: .displayP3, pixels: pixels)
    }

    @Test("The canvas draws something rather than nothing")
    func canvasDrawsSomething() throws {
        let drawn = try canvasPixels(of: Self.scene)
        #expect(drawn.width > 0)
        #expect(drawn.pixels.contains { $0 != 0 })
    }

    @Test("What the canvas draws is the size of what the exporter writes")
    func sameSize() throws {
        let exported = try CoreGraphicsRenderer().render(
            DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(Self.scene),
            scale: 1
        )
        let drawn = try canvasPixels(of: Self.scene)
        #expect(drawn.width == exported.bitmap.width)
        #expect(drawn.height == exported.bitmap.height)
    }

    @Test("Where the exporter puts ink, so does the canvas")
    func inkInTheSamePlaces() throws {
        let exported = try CoreGraphicsRenderer().render(
            DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(Self.scene),
            scale: 1
        )
        let drawn = try canvasPixels(of: Self.scene)

        var exportedInk = 0
        var agreed = 0
        let channels = 4
        for pixel in stride(from: 0, to: min(drawn.pixels.count, exported.bitmap.pixels.count), by: channels)
        {
            let exportedAlpha = exported.bitmap.pixels[pixel]
            let drawnAlpha = drawn.pixels[pixel]
            guard exportedAlpha > Ink.threshold else { continue }
            exportedInk += 1
            if drawnAlpha > Ink.threshold { agreed += 1 }
        }

        #expect(exportedInk > 0)
        #expect(Double(agreed) / Double(exportedInk) > Ink.agreement)
    }

    @Test("Picking something up does not change what is on the canvas")
    func draggingDoesNotChangeThePicture() throws {
        let view = CanvasView(scene: Self.scene)
        view.frame = NSRect(x: 0, y: 0, width: 560, height: 360)
        view.layoutSubtreeIfNeeded()
        #expect(view.moving.isEmpty)

        view.beginMoving([AnnotationID(1)])
        #expect(view.moving == [AnnotationID(1)])

        view.endMoving()
        #expect(view.moving.isEmpty)
    }

    private enum Ink {
        static let threshold: UInt8 = 8
        static let agreement = 0.95
    }
}
