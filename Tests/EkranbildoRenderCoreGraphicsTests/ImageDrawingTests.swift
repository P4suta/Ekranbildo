import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoImaging
@testable import EkranbildoRenderCoreGraphics
import Testing

@Suite("Image drawing")
struct ImageDrawingTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 40, height: 30)

    private func twoTone() -> ImageBuffer {
        var screen = SyntheticScreenshot(
            width: 40, height: 30, background: .opaque(red: 255, green: 0, blue: 0))
        screen.paint(
            SceneRect(x: 0, y: 15, width: 40, height: 15),
            color: .opaque(red: 0, green: 0, blue: 255)
        )
        return screen.image
    }

    private func drawn(assets: (any AssetStoring)?, ref: ImageRef) throws -> RenderResult {
        try CoreGraphicsRenderer(assets: assets).render(
            DrawList(
                canvas: Self.canvas,
                colorSpace: .sRGB,
                commands: [.image(ref, Self.canvas, opacity: 1, cornerRadius: 0)]
            ),
            scale: 1
        )
    }

    @Test("A stored picture is drawn the way up it was stored")
    func orientation() throws {
        var store = InMemoryAssetStore()
        let ref = store.store(twoTone())
        let result = try drawn(assets: store, ref: ref)

        #expect(result.warnings.isEmpty)
        let top = result.bitmap.pixel(x: 20, y: 5)
        let bottom = result.bitmap.pixel(x: 20, y: 25)
        #expect(top.red > top.blue, "the picture is upside down")
        #expect(bottom.blue > bottom.red, "the picture is upside down")
    }

    @Test("A picture nobody stored is reported rather than skipped")
    func missingPicture() throws {
        let result = try drawn(
            assets: InMemoryAssetStore(),
            ref: ImageRef(contentHash: "absent", pixelWidth: 40, pixelHeight: 30)
        )
        #expect(result.warnings.contains { $0.code == RenderWarning.imageUnresolved })
    }

    @Test("A renderer with no store at all reports rather than drawing a hole")
    func noStore() throws {
        let result = try drawn(
            assets: nil,
            ref: ImageRef(contentHash: "absent", pixelWidth: 40, pixelHeight: 30)
        )
        #expect(result.warnings.contains { $0.code == RenderWarning.imageUnresolved })
    }

    @Test("A picture is drawn into the rectangle it was given")
    func placement() throws {
        var store = InMemoryAssetStore()
        let ref = store.store(twoTone())
        let half = SceneRect(x: 0, y: 0, width: 20, height: 30)
        let result = try CoreGraphicsRenderer(assets: store).render(
            DrawList(
                canvas: Self.canvas,
                colorSpace: .sRGB,
                commands: [.image(ref, half, opacity: 1, cornerRadius: 0)]
            ),
            scale: 1
        )
        #expect(result.bitmap.pixel(x: 5, y: 5).alpha > 0)
        #expect(result.bitmap.pixel(x: 35, y: 5).alpha == 0, "it spilled outside its rectangle")
    }
}
