import CoreGraphics
import EkranbildoContracts
import EkranbildoFixtures
@testable import EkranbildoImaging
import Testing

@Suite("Core Graphics bridge")
struct CGImageBridgeTests {

    @Test("A buffer converts to an image of the same size")
    func size() throws {
        let screen = SceneLibrary.applicationWindow
        let converted = try ImageCodec.cgImage(of: screen.image)
        #expect(converted.width == screen.width)
        #expect(converted.height == screen.height)
    }

    @Test("Colours survive the round trip")
    func colours() throws {
        let screen = SceneLibrary.applicationWindow
        let original = screen.image
        let returned = try ImageCodec.buffer(
            from: ImageCodec.cgImage(of: original), into: original.colorSpace)

        for y in stride(from: 0, to: original.height, by: 7) {
            for x in stride(from: 0, to: original.width, by: 7) {
                #expect(returned[x: x, y: y] == original[x: x, y: y], "pixel \(x),\(y) changed")
            }
        }
    }

    @Test("An empty buffer is reported rather than converted")
    func empty() {
        #expect(throws: RenderError.self) {
            try ImageCodec.cgImage(of: ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []))
        }
    }
}
