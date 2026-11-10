@testable import EkranbildoContracts
import EkranbildoGeometry
import Testing

@Suite("ImageBuffer")
struct ImageBufferTests {

    private func solid(
        width: Int,
        height: Int,
        red: UInt8 = 0,
        green: UInt8 = 0,
        blue: UInt8 = 0
    ) -> ImageBuffer {
        ImageBuffer(
            width: width,
            height: height,
            colorSpace: .sRGB,
            pixels: (0..<(width * height)).flatMap { _ in [red, green, blue, UInt8.max] }
        )
    }

    @Test("A buffer reports the size it was built with")
    func dimensions() {
        let image = solid(width: 4, height: 3)
        #expect(image.width == 4)
        #expect(image.height == 3)
        #expect(image.pixelCount == 12)
    }

    @Test("Pixels are addressed by coordinate")
    func pixelAccess() {
        var pixels: [UInt8] = []
        for index in 0..<6 {
            pixels.append(contentsOf: [UInt8(index * 10), 0, 0, UInt8.max])
        }
        let image = ImageBuffer(width: 3, height: 2, colorSpace: .sRGB, pixels: pixels)
        #expect(image[x: 0, y: 0].red == 0)
        #expect(image[x: 2, y: 0].red == 20)
        #expect(image[x: 0, y: 1].red == 30)
        #expect(image[x: 2, y: 1].red == 50)
    }

    @Test("Coordinates outside the image clamp to the nearest edge")
    func clamping() {
        var pixels: [UInt8] = []
        for index in 0..<4 {
            pixels.append(contentsOf: [UInt8(index + 1), 0, 0, UInt8.max])
        }
        let image = ImageBuffer(width: 2, height: 2, colorSpace: .sRGB, pixels: pixels)
        #expect(image[x: -5, y: -5].red == image[x: 0, y: 0].red)
        #expect(image[x: 99, y: 99].red == image[x: 1, y: 1].red)
        #expect(image[x: -1, y: 1].red == image[x: 0, y: 1].red)
    }

    @Test("An empty buffer is valid and reports no pixels")
    func empty() {
        let image = ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: [])
        #expect(image.pixelCount == 0)
        #expect(image.isEmpty)
    }

    @Test("A buffer given too few bytes reports itself as invalid rather than trapping")
    func truncated() {
        let image = ImageBuffer(width: 4, height: 4, colorSpace: .sRGB, pixels: [1, 2, 3])
        #expect(!image.isWellFormed)
        #expect(image[x: 2, y: 2] == .transparent)
    }

    @Test("Luminance follows the usual weighting of the channels")
    func luminance() {
        #expect(ImageBuffer.Pixel(red: 0, green: 0, blue: 0, alpha: 255).luminance == 0)
        #expect(
            approximatelyEqual(
                ImageBuffer.Pixel(red: 255, green: 255, blue: 255, alpha: 255).luminance,
                1,
                tolerance: 1e-9
            )
        )
        let green = ImageBuffer.Pixel(red: 0, green: 255, blue: 0, alpha: 255).luminance
        let red = ImageBuffer.Pixel(red: 255, green: 0, blue: 0, alpha: 255).luminance
        let blue = ImageBuffer.Pixel(red: 0, green: 0, blue: 255, alpha: 255).luminance
        #expect(green > red)
        #expect(red > blue)
    }

    @Test("The image knows its own bounds in scene coordinates")
    func bounds() {
        #expect(solid(width: 8, height: 6).bounds == SceneRect(x: 0, y: 0, width: 8, height: 6))
    }
}
