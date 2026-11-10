import EkranbildoContracts
import EkranbildoImaging
@testable import EkranbildoRenderCoreGraphics
import EkranbildoTestKit
import Testing

@Suite("Drawing over a picture")
struct OverPictureTests {

    private func picture(
        width: Int = 40,
        height: Int = 20,
        red: UInt8 = 0,
        green: UInt8 = 200,
        blue: UInt8 = 0
    ) -> ImageBuffer {
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height * ImageBuffer.Channel.count)
        for _ in 0..<(width * height) {
            pixels.append(contentsOf: [red, green, blue, 255])
        }
        return ImageBuffer(width: width, height: height, colorSpace: .sRGB, pixels: pixels)
    }

    private let canvas = SceneRect(x: 0, y: 0, width: 40, height: 20)
    private let red = Color(red: 1, green: 0, blue: 0, alpha: 1)

    private func drawn(
        _ commands: [DrawCommand],
        over image: ImageBuffer
    ) throws -> RenderedBitmap {
        try CoreGraphicsRenderer()
            .render(
                DrawList(canvas: canvas, colorSpace: .sRGB, commands: commands),
                over: image
            )
            .bitmap
    }

    @Test("Drawing nothing leaves the picture exactly as it was")
    func nothingDrawn() throws {
        let bitmap = try drawn([], over: picture())
        let pixel = bitmap.pixel(x: 20, y: 10)
        #expect(pixel.red == 0)
        #expect(pixel.green == 200)
        #expect(pixel.blue == 0)
        #expect(pixel.alpha == 255)
    }

    @Test("What is drawn covers the picture underneath")
    func coversWhereDrawn() throws {
        let shape = SceneRect(x: 0, y: 0, width: 10, height: 20)
        let bitmap = try drawn([.fill(Path.rect(shape), .solid(red))], over: picture())
        #expect(bitmap.pixel(x: 5, y: 10).red == 255)
        #expect(bitmap.pixel(x: 5, y: 10).green == 0)
    }

    @Test("The picture is untouched where nothing was drawn")
    func leavesTheRestAlone() throws {
        let shape = SceneRect(x: 0, y: 0, width: 10, height: 20)
        let bitmap = try drawn([.fill(Path.rect(shape), .solid(red))], over: picture())
        #expect(bitmap.pixel(x: 30, y: 10).green == 200)
        #expect(bitmap.pixel(x: 30, y: 10).red == 0)
    }

    @Test("The result is the size of the picture")
    func keepsThePictureSize() throws {
        let bitmap = try drawn([], over: picture(width: 64, height: 48))
        #expect(bitmap.width == 64)
        #expect(bitmap.height == 48)
    }

    @Test("A picture larger than the canvas is drawn to scale")
    func scalesToThePicture() throws {
        let shape = SceneRect(x: 0, y: 0, width: 10, height: 20)
        let bitmap = try drawn(
            [.fill(Path.rect(shape), .solid(red))], over: picture(width: 80, height: 40))
        #expect(bitmap.width == 80)
        #expect(bitmap.pixel(x: 15, y: 20).red == 255)
        #expect(bitmap.pixel(x: 25, y: 20).green == 200)
    }

    @Test("A picture with no pixels is refused rather than crashed on")
    func emptyPicture() {
        #expect(throws: (any Error).self) {
            try drawn([], over: ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []))
        }
    }

    @Test("Drawing over a picture is reproducible")
    func reproducible() throws {
        let shape = SceneRect(x: 4, y: 4, width: 10, height: 8)
        let commands: [DrawCommand] = [.fill(Path.roundedRect(shape, radius: 3), .solid(red))]
        let source = picture()
        #expect(try isReproducible { try drawn(commands, over: source).pixels })
    }

    @Test("A picture drawn over and read back is the picture it was")
    func roundTripsThroughTheContext() throws {
        let source = picture(red: 30, green: 200, blue: 90)
        let back = try drawn([], over: source).imageBuffer
        #expect(back == source)
    }

    @Test("A translucent picture survives the round trip", arguments: [UInt8(255), 128, 1])
    func roundTripsTranslucency(alpha: UInt8) throws {
        var pixels: [UInt8] = []
        for _ in 0..<(4 * 2) { pixels.append(contentsOf: [255, 128, 0, alpha]) }
        let source = ImageBuffer(width: 4, height: 2, colorSpace: .sRGB, pixels: pixels)

        let back = try CoreGraphicsRenderer()
            .render(
                DrawList(
                    canvas: SceneRect(x: 0, y: 0, width: 4, height: 2),
                    colorSpace: .sRGB,
                    commands: []
                ),
                over: source
            )
            .bitmap
            .imageBuffer

        let pixel = back[x: 0, y: 0]
        #expect(pixel.alpha == alpha)
        #expect(abs(Int(pixel.red) - 255) <= Tolerances.channel(at: alpha))
        #expect(abs(Int(pixel.green) - 128) <= Tolerances.channel(at: alpha))
    }

    private enum Tolerances {
        static func channel(at alpha: UInt8) -> Int {
            Int(Double(ImageBuffer.Channel.maximum) / (2 * Double(max(1, alpha)))) + 1
        }
    }
}
