import CoreGraphics
import EkranbildoContracts
import EkranbildoImaging

extension CoreGraphicsRenderer {
    static func fill(_ storage: UnsafeMutableRawPointer, bytesPerRow: Int, from image: ImageBuffer) {
        let bytes = storage.initializeMemory(
            as: UInt8.self, repeating: 0, count: bytesPerRow * image.height)
        for row in 0..<image.height {
            for column in 0..<image.width {
                let pixel = image[x: column, y: row]
                let offset = row * bytesPerRow + column * PixelFormat.bytesPerPixel
                let alpha = Int(pixel.alpha)
                func premultiplied(_ value: UInt8) -> UInt8 {
                    UInt8((Int(value) * alpha + Rounding.half) / PixelFormat.maximumChannelValue)
                }
                bytes[offset + PixelFormat.Offset.blue] = premultiplied(pixel.blue)
                bytes[offset + PixelFormat.Offset.green] = premultiplied(pixel.green)
                bytes[offset + PixelFormat.Offset.red] = premultiplied(pixel.red)
                bytes[offset + PixelFormat.Offset.alpha] = pixel.alpha
            }
        }
    }

    private enum Rounding {
        static let half = PixelFormat.maximumChannelValue / halves
        private static let halves = 2
    }
}
