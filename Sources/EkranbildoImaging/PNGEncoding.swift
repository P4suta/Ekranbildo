import CoreGraphics
import EkranbildoContracts
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension RenderedBitmap {
    public func pngData() throws -> [UInt8] {
        var bytes = pixels
        guard
            let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: PixelFormat.bitsPerComponent,
                bitsPerPixel: PixelFormat.bitsPerPixel,
                bytesPerRow: bytesPerRow,
                space: CoreGraphicsColorSpace.resolve(colorSpace),
                bitmapInfo: CGBitmapInfo(rawValue: PixelFormat.bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw RenderError(code: RenderError.encodingFailed, detail: "could not build a CGImage")
        }
        bytes.removeAll()

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, UTType.png.identifier as CFString, 1, nil)
        else {
            throw RenderError(
                code: RenderError.encodingFailed, detail: "could not create a PNG destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError(code: RenderError.encodingFailed, detail: "PNG finalisation failed")
        }
        return [UInt8](output as Data)
    }
}
