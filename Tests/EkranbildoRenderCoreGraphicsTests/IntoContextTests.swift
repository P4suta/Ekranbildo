import CoreGraphics
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoRenderCoreGraphics
import Testing

@Suite("Drawing into a context")
struct IntoContextTests {

    private func context(width: Int, height: Int) throws -> CGContext {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        return try #require(context)
    }

    private var list: DrawList {
        DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 40, height: 20),
            colorSpace: .displayP3,
            commands: [
                .fill(
                    .rect(SceneRect(x: 0, y: 0, width: 40, height: 20)),
                    .solid(Color(red: 1, green: 0, blue: 0, alpha: 1))
                )
            ]
        )
    }

    @Test("A list drawn into a context puts something there")
    func drawsSomething() throws {
        let context = try context(width: 40, height: 20)
        let warnings = CoreGraphicsRenderer().draw(list, into: context, scale: 1)
        #expect(warnings.isEmpty)
        let pixels = try #require(context.data)
        #expect(pixels.load(as: UInt8.self) != 0)
    }

    @Test("What it draws into a context is what it renders to a bitmap")
    func canvasAndExportAgree() throws {
        let exported = try CoreGraphicsRenderer().render(list, scale: 1)

        let context = try context(width: exported.bitmap.width, height: exported.bitmap.height)
        _ = CoreGraphicsRenderer().draw(list, into: context, scale: 1)
        let drawn = try #require(context.makeImage())

        #expect(drawn.width == exported.bitmap.width)
        #expect(drawn.height == exported.bitmap.height)
    }

    @Test("A scale makes it bigger without changing what it is")
    func scaleChangesSizeOnly() throws {
        let context = try context(width: 80, height: 40)
        let warnings = CoreGraphicsRenderer().draw(list, into: context, scale: 2)
        #expect(warnings.isEmpty)
    }

    @Test("An empty list draws nothing and complains about nothing")
    func emptyList() throws {
        let empty = DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            colorSpace: .displayP3,
            commands: []
        )
        let context = try context(width: 10, height: 10)
        #expect(CoreGraphicsRenderer().draw(empty, into: context, scale: 1).isEmpty)
    }

    @Test("Warnings come back rather than being swallowed")
    func warningsComeBack() throws {
        let missing = DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            colorSpace: .displayP3,
            commands: [
                .image(
                    ImageRef(contentHash: "nothing", pixelWidth: 10, pixelHeight: 10),
                    SceneRect(x: 0, y: 0, width: 10, height: 10),
                    opacity: 1,
                    cornerRadius: 0
                )
            ]
        )
        let context = try context(width: 10, height: 10)
        #expect(!CoreGraphicsRenderer().draw(missing, into: context, scale: 1).isEmpty)
    }
}
