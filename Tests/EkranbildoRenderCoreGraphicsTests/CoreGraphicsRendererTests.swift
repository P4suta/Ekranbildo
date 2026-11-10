import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoImaging
@testable import EkranbildoRenderCoreGraphics
import EkranbildoTestKit
import Testing

@Suite("CoreGraphicsRenderer")
struct CoreGraphicsRendererTests {
    private let canvas = SceneRect(x: 0, y: 0, width: 40, height: 20)

    private func render(_ commands: [DrawCommand], scale: Double = 1) throws -> RenderedBitmap {
        try CoreGraphicsRenderer()
            .render(DrawList(canvas: canvas, colorSpace: .sRGB, commands: commands), scale: scale)
            .bitmap
    }

    @Test("The bitmap is the canvas size in points multiplied by the scale")
    func dimensions() throws {
        #expect(try render([]).width == 40)
        #expect(try render([]).height == 20)
        #expect(try render([], scale: 2).width == 80)
        #expect(try render([], scale: 2).height == 40)
    }

    @Test("An empty list renders fully transparent")
    func emptyIsTransparent() throws {
        let bitmap = try render([])
        #expect(bitmap.pixel(x: 20, y: 10).alpha == 0)
    }

    @Test("A filled rectangle puts its colour on the pixels it covers")
    func solidFill() throws {
        let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
        let bitmap = try render([.fill(Path.rect(canvas), .solid(red))])
        let pixel = bitmap.pixel(x: 20, y: 10)
        #expect(pixel.red == 255)
        #expect(pixel.green == 0)
        #expect(pixel.blue == 0)
        #expect(pixel.alpha == 255)
    }

    @Test("A fill only covers its own path")
    func fillIsBounded() throws {
        let blue = Color(red: 0, green: 0, blue: 1, alpha: 1)
        let bitmap = try render([
            .fill(Path.rect(SceneRect(x: 0, y: 0, width: 10, height: 20)), .solid(blue))
        ])
        #expect(bitmap.pixel(x: 5, y: 10).blue == 255)
        #expect(bitmap.pixel(x: 30, y: 10).alpha == 0)
    }

    @Test("The Y axis is flipped so scene coordinates land where they should")
    func verticalOrientation() throws {
        let green = Color(red: 0, green: 1, blue: 0, alpha: 1)
        let bitmap = try render([
            .fill(Path.rect(SceneRect(x: 0, y: 0, width: 40, height: 5)), .solid(green))
        ])
        #expect(bitmap.pixel(x: 20, y: 2).green == 255)
        #expect(bitmap.pixel(x: 20, y: 17).alpha == 0)
    }

    @Test("A stroke covers the line it follows")
    func stroke() throws {
        let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
        let bitmap = try render([
            .stroke(
                Path.polyline(Polyline(points: [P2(x: 0, y: 10), P2(x: 40, y: 10)])),
                Stroke(paint: .solid(black), width: 4)
            )
        ])
        #expect(bitmap.pixel(x: 20, y: 10).alpha == 255)
        #expect(bitmap.pixel(x: 20, y: 2).alpha == 0)
    }

    @Test("Rendering at a higher scale keeps the same geometry in points")
    func scaleIsResolutionOnly() throws {
        let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
        let commands: [DrawCommand] = [
            .fill(Path.rect(SceneRect(x: 0, y: 0, width: 20, height: 20)), .solid(red))
        ]
        let atOneX = try render(commands, scale: 1)
        let atTwoX = try render(commands, scale: 2)
        #expect(atOneX.pixel(x: 10, y: 10).red == 255)
        #expect(atTwoX.pixel(x: 20, y: 20).red == 255)
        #expect(atOneX.pixel(x: 30, y: 10).alpha == 0)
        #expect(atTwoX.pixel(x: 60, y: 20).alpha == 0)
    }

    @Test("Rendering the same list twice produces identical pixels")
    func reproducible() throws {
        let commands: [DrawCommand] = [
            .fill(
                Path.roundedRect(SceneRect(x: 4, y: 4, width: 30, height: 12), cornerRadius: 4),
                .solid(Color(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            )
        ]
        #expect(try isReproducible { try render(commands).pixels })
    }
}

@Suite("PNG encoding")
struct PNGEncodingTests {

    @Test("Encoding produces a PNG with the right magic number")
    func pngMagic() throws {
        let bitmap = try CoreGraphicsRenderer().render(
            DrawList(
                canvas: SceneRect(x: 0, y: 0, width: 8, height: 8),
                colorSpace: .sRGB,
                commands: []
            ),
            scale: 1
        ).bitmap
        let bytes = try bitmap.pngData()
        #expect(bytes.prefix(8) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    @Test("Encoding is not empty for a drawn image")
    func nonEmpty() throws {
        let bitmap = try CoreGraphicsRenderer().render(
            DrawList(
                canvas: SceneRect(x: 0, y: 0, width: 16, height: 16),
                colorSpace: .sRGB,
                commands: [
                    .fill(
                        Path.rect(SceneRect(x: 0, y: 0, width: 16, height: 16)),
                        .solid(Color(red: 1, green: 1, blue: 0, alpha: 1))
                    )
                ]
            ),
            scale: 1
        ).bitmap
        #expect(try bitmap.pngData().count > 50)
    }
}
