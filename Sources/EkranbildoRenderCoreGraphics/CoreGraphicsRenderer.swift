import CoreGraphics
import CoreText
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoObservability
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct CoreGraphicsRenderer: Sendable {
    let assets: (any AssetStoring)?

    public init(assets: (any AssetStoring)? = nil) {
        self.assets = assets
    }

    public func render(_ list: DrawList, scale: Double) throws -> RenderResult {
        let width = max(1, Int((list.canvas.width * scale).rounded()))
        let height = max(1, Int((list.canvas.height * scale).rounded()))
        return try render(list, into: width, by: height, at: scale, over: nil)
    }

    public func render(_ list: DrawList, over image: ImageBuffer) throws -> RenderResult {
        guard image.width > 0, image.height > 0 else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "there is no picture to draw over"
            )
        }
        return try render(
            list,
            into: image.width,
            by: image.height,
            at: Double(image.width) / max(Scale.smallestCanvas, list.canvas.width),
            over: image
        )
    }

    @discardableResult
    public func draw(_ list: DrawList, into context: CGContext, scale: Double) -> [RenderWarning] {
        configureForDeterminism(context)

        let height = list.canvas.height * scale

        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: CGFloat(-scale))
        context.translateBy(x: CGFloat(-list.canvas.minX), y: CGFloat(-list.canvas.minY))

        var warnings: [RenderWarning] = []
        for command in list.commands {
            draw(command, in: context, warnings: &warnings)
        }
        return Self.deduplicated(warnings)
    }

    private func render(
        _ list: DrawList,
        into width: Int,
        by height: Int,
        at scale: Double,
        over image: ImageBuffer?
    ) throws -> RenderResult {
        let bytesPerRow = PixelFormat.bytesPerRow(width: width)

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: bytesPerRow * height,
            alignment: MemoryLayout<UInt32>.alignment
        )
        defer { storage.deallocate() }

        if let image {
            Self.fill(storage, bytesPerRow: bytesPerRow, from: image)
        } else {
            storage.initializeMemory(
                as: UInt8.self, repeating: 0, count: bytesPerRow * height)
        }

        guard
            let context = CGContext(
                data: storage,
                width: width,
                height: height,
                bitsPerComponent: PixelFormat.bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: CoreGraphicsColorSpace.resolve(list.colorSpace),
                bitmapInfo: PixelFormat.bitmapInfo
            )
        else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "could not create a \(width)x\(height) bitmap context"
            )
        }

        let warnings = draw(list, into: context, scale: scale)

        guard let data = context.data else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "bitmap context exposed no backing store"
            )
        }
        let buffer = UnsafeRawBufferPointer(start: data, count: bytesPerRow * height)

        return RenderResult(
            bitmap: RenderedBitmap(
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                colorSpace: list.colorSpace,
                pixels: [UInt8](buffer)
            ),
            warnings: warnings
        )
    }

    private enum Scale {
        static let smallestCanvas: Double = 1
    }

    private func configureForDeterminism(_ context: CGContext) {
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSmoothing(false)
        context.setShouldSubpixelPositionFonts(false)
        context.setAllowsFontSubpixelPositioning(false)
        context.setShouldSubpixelQuantizeFonts(false)
        context.setAllowsFontSubpixelQuantization(false)
        context.interpolationQuality = .high
    }
}
