import CoreGraphics
import EkranbildoContracts
import EkranbildoImaging

extension CoreGraphicsRenderer {

    func draw(_ shadow: Shadow, under path: Path, in context: CGContext) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: shadow.offset.x, height: -shadow.offset.y),
            blur: shadow.blur / Shadowing.blurToRadius,
            color: Self.cgColor(shadow.color, in: context)
        )
        context.setFillColor(Self.cgColor(shadow.color.opaque, in: context))
        if let cgPath = Self.makePath(path) {
            context.addPath(cgPath)
            context.fillPath()
        }
        context.restoreGState()
    }

    struct Picture {
        let ref: ImageRef
        let rect: SceneRect
        let opacity: Double
        let cornerRadius: Double
    }

    func draw(
        _ picture: Picture,
        in context: CGContext,
        warnings: inout [RenderWarning]
    ) {
        let ref = picture.ref
        let rect = picture.rect
        let opacity = picture.opacity
        let cornerRadius = picture.cornerRadius
        guard let buffer = assets?.image(for: ref),
            let image = try? ImageCodec.cgImage(of: buffer)
        else {
            warnings.append(
                RenderWarning(
                    code: RenderWarning.imageUnresolved,
                    detail: "no pixels available for image '\(ref.contentHash)'"
                )
            )
            return
        }
        context.saveGState()
        context.setAlpha(opacity)
        if cornerRadius > 0, let rounded = Self.makePath(Path.roundedRect(rect, radius: cornerRadius)) {
            context.addPath(rounded)
            context.clip()
        }
        context.translateBy(x: 0, y: rect.minY + rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(
            image,
            in: CGRect(
                x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        )
        context.restoreGState()
    }
}
