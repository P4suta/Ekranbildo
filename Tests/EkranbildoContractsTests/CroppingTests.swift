@testable import EkranbildoContracts
import Testing

@Suite("Cropping")
struct CroppingTests {

    private func numbered(width: Int, height: Int) -> ImageBuffer {
        var pixels: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                pixels.append(contentsOf: [UInt8(x), UInt8(y), 0, 255])
            }
        }
        return ImageBuffer(
            width: width, height: height, colorSpace: .displayP3, pixels: pixels)
    }

    @Test("A crop is the size it was asked for")
    func sizeIsAsAsked() throws {
        let cropped = try #require(
            numbered(width: 10, height: 8).cropped(to: ImageRect(x: 2, y: 1, width: 4, height: 3)))
        #expect(cropped.width == 4)
        #expect(cropped.height == 3)
    }

    @Test("A crop takes the pixels that were there")
    func takesTheRightPixels() throws {
        let cropped = try #require(
            numbered(width: 10, height: 8).cropped(to: ImageRect(x: 2, y: 1, width: 4, height: 3)))
        let corner = cropped[x: 0, y: 0]
        #expect(corner.red == 2)
        #expect(corner.green == 1)

        let opposite = cropped[x: 3, y: 2]
        #expect(opposite.red == 5)
        #expect(opposite.green == 3)
    }

    @Test("A crop of the whole picture is the picture")
    func wholePicture() throws {
        let original = numbered(width: 4, height: 4)
        let cropped = try #require(
            original.cropped(to: ImageRect(x: 0, y: 0, width: 4, height: 4)))
        #expect(cropped.pixels == original.pixels)
    }

    @Test(
        "A rectangle that leaves the picture is refused",
        arguments: [
            ImageRect(x: -1, y: 0, width: 2, height: 2),
            ImageRect(x: 0, y: -1, width: 2, height: 2),
            ImageRect(x: 3, y: 0, width: 2, height: 2),
            ImageRect(x: 0, y: 3, width: 2, height: 2),
        ])
    func outOfBoundsIsRefused(rect: ImageRect) {
        #expect(numbered(width: 4, height: 4).cropped(to: rect) == nil)
    }

    @Test("A rectangle with no area is refused")
    func emptyIsRefused() {
        let picture = numbered(width: 4, height: 4)
        #expect(picture.cropped(to: ImageRect(x: 0, y: 0, width: 0, height: 2)) == nil)
        #expect(picture.cropped(to: ImageRect(x: 0, y: 0, width: 2, height: 0)) == nil)
    }

    @Test("A rectangle between pixels is rounded rather than refused")
    func fractionalIsRounded() throws {
        let cropped = try #require(
            numbered(width: 10, height: 8)
                .cropped(to: ImageRect(x: 2.4, y: 1.6, width: 4.2, height: 3.1)))
        #expect(cropped.width == 4)
        #expect(cropped.height == 3)
    }

    @Test("What comes out keeps the colour space of what went in")
    func keepsTheColourSpace() throws {
        let cropped = try #require(
            numbered(width: 4, height: 4).cropped(to: ImageRect(x: 1, y: 1, width: 2, height: 2)))
        #expect(cropped.colorSpace == .displayP3)
    }
}
