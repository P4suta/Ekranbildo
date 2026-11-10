import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoImaging
import EkranbildoTestKit
import Foundation
import Testing

@Suite("Image decoding")
struct ImageDecodingTests {

    private func encodedSample() throws -> [UInt8] {
        var screen = SyntheticScreenshot(width: 32, height: 24)
        screen.add(
            SceneRect(x: 4, y: 4, width: 12, height: 8),
            color: .opaque(red: 200, green: 30, blue: 40),
            named: "block"
        )
        return try ImageCodec.encodePNG(screen.image)
    }

    @Test("A buffer survives a round trip through PNG")
    func roundTrip() throws {
        var screen = SyntheticScreenshot(width: 16, height: 12)
        screen.add(
            SceneRect(x: 2, y: 2, width: 6, height: 4),
            color: .opaque(red: 10, green: 200, blue: 90),
            named: "block"
        )
        let original = screen.image

        let decoded = try ImageCodec.decode(try ImageCodec.encodePNG(original), into: original.colorSpace)
            .image
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)

        for y in 0..<original.height {
            for x in 0..<original.width {
                #expect(decoded[x: x, y: y] == original[x: x, y: y], "pixel \(x),\(y) changed")
            }
        }
    }

    @Test("Decoded images are well formed")
    func wellFormed() throws {
        let decoded = try ImageCodec.decode(try encodedSample(), into: .sRGB).image
        #expect(decoded.isWellFormed)
        #expect(decoded.pixelCount == 32 * 24)
    }

    @Test("Bytes that are not an image are reported rather than trapping")
    func malformedInput() {
        #expect(throws: RenderError.self) {
            _ = try ImageCodec.decode([0x00, 0x01, 0x02, 0x03])
        }
        #expect(throws: RenderError.self) {
            _ = try ImageCodec.decode([])
        }
    }

    @Test("Decoding is reproducible")
    func reproducible() throws {
        let bytes = try encodedSample()
        #expect(isReproducible { try? ImageCodec.decode(bytes).image.pixels })
    }

    @Test("What was drawn is still detectable after a round trip")
    func survivesForDetection() throws {
        var screen = SyntheticScreenshot(width: 120, height: 80)
        screen.add(
            SceneRect(x: 20, y: 20, width: 60, height: 30),
            color: .opaque(red: 60, green: 120, blue: 220),
            named: "button"
        )
        let decoded = try ImageCodec.decode(
            try ImageCodec.encodePNG(screen.image), into: screen.image.colorSpace
        ).image

        for y in 0..<screen.height {
            for x in 0..<screen.width {
                #expect(decoded[x: x, y: y] == screen.image[x: x, y: y])
            }
        }
    }
}
