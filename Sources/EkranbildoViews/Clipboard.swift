import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoExport
import EkranbildoFixtures
import EkranbildoRender
import EkranbildoRenderCoreGraphics

public enum Clipboard {
    public static func png(
        of scene: Scene,
        assets: (any AssetStoring)?,
        scale: Double
    ) throws -> [UInt8] {
        let drawing = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(scene)
        let rendered = try CoreGraphicsRenderer(assets: assets).render(drawing, scale: scale)
        return try Exporter().export(rendered.bitmap.imageBuffer, as: .png)
    }

    public static func put(_ png: [UInt8], on board: NSPasteboard) -> Bool {
        board.clearContents()
        guard !png.isEmpty else { return false }
        return board.setData(Data(png), forType: .png)
    }
}
