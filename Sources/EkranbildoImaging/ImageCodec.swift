import CoreGraphics
import EkranbildoContracts
import EkranbildoObservability
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct DecodedImage: Sendable {
    public let image: ImageBuffer
    public let sourceColorSpace: String

    public init(image: ImageBuffer, sourceColorSpace: String) {
        self.image = image
        self.sourceColorSpace = sourceColorSpace
    }

    public var colorSpace: CanonicalColorSpace { image.colorSpace }
    public var width: Int { image.width }
    public var height: Int { image.height }
}

public enum ImageCodec {

    public static func decode(
        _ bytes: [UInt8],
        into destination: CanonicalColorSpace = .workingSpace
    ) throws -> DecodedImage {
        guard !bytes.isEmpty,
            let source = CGImageSourceCreateWithData(Data(bytes) as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw RenderError(
                code: RenderError.undecodableImage,
                detail: "the bytes given are not an image this system can read"
            )
        }
        return DecodedImage(
            image: try buffer(from: image, into: destination),
            sourceColorSpace: Self.name(of: image.colorSpace)
        )
    }

    static func name(of space: CGColorSpace?) -> String {
        guard let space else { return "untagged" }
        return (space.name as String?) ?? "unnamed profile"
    }

    public static func buffer(
        from image: CGImage,
        into destination: CanonicalColorSpace = .workingSpace
    ) throws -> ImageBuffer {
        let width = image.width
        let height = image.height
        let bytesPerRow = PixelFormat.bytesPerRow(width: width)

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: PixelFormat.bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: CoreGraphicsColorSpace.resolve(destination),
                bitmapInfo: PixelFormat.bitmapInfo
            )
        else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "could not create a \(width)x\(height) context to decode into"
            )
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "decode context exposed no backing store"
            )
        }

        let raw = UnsafeRawBufferPointer(start: data, count: bytesPerRow * height)
        var pixels = [UInt8](repeating: 0, count: width * height * ImageBuffer.Channel.count)
        for index in 0..<(width * height) {
            let source = index * PixelFormat.bytesPerPixel
            let alpha = raw[source + PixelFormat.Offset.alpha]
            let destination = index * ImageBuffer.Channel.count

            func straighten(_ value: UInt8) -> UInt8 {
                guard alpha > 0, alpha < UInt8(PixelFormat.maximumChannelValue) else { return value }
                let full = Double(PixelFormat.maximumChannelValue)
                return UInt8(
                    min(PixelFormat.maximumChannelValue, Int(Double(value) * full / Double(alpha))))
            }

            let channel = ImageBuffer.Channel.Offset.self
            pixels[destination + channel.red] = straighten(raw[source + PixelFormat.Offset.red])
            pixels[destination + channel.green] = straighten(raw[source + PixelFormat.Offset.green])
            pixels[destination + channel.blue] = straighten(raw[source + PixelFormat.Offset.blue])
            pixels[destination + channel.alpha] = alpha
        }

        return ImageBuffer(width: width, height: height, colorSpace: destination, pixels: pixels)
    }

    public static func properties(of bytes: [UInt8]) throws -> [String: Any] {
        guard !bytes.isEmpty,
            let source = CGImageSourceCreateWithData(Data(bytes) as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [String: Any]
        else {
            throw RenderError(
                code: RenderError.undecodableImage,
                detail: "the bytes given are not an image this system can read"
            )
        }
        return properties
    }

    public static func encodePNG(_ image: ImageBuffer) throws -> [UInt8] {
        guard image.isWellFormed, !image.isEmpty else {
            throw RenderError(code: RenderError.encodingFailed, detail: "nothing to encode")
        }

        let bytesPerRow = PixelFormat.bytesPerRow(width: image.width)
        var premultiplied = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        for index in 0..<(image.width * image.height) {
            let source = index * ImageBuffer.Channel.count
            let destination = index * PixelFormat.bytesPerPixel
            let channel = ImageBuffer.Channel.Offset.self
            let alpha = image.pixels[source + channel.alpha]

            func premultiply(_ value: UInt8) -> UInt8 {
                guard alpha < UInt8(PixelFormat.maximumChannelValue) else { return value }
                return UInt8(Int(value) * Int(alpha) / PixelFormat.maximumChannelValue)
            }

            premultiplied[destination + PixelFormat.Offset.red] = premultiply(
                image.pixels[source + channel.red])
            premultiplied[destination + PixelFormat.Offset.green] = premultiply(
                image.pixels[source + channel.green])
            premultiplied[destination + PixelFormat.Offset.blue] = premultiply(
                image.pixels[source + channel.blue])
            premultiplied[destination + PixelFormat.Offset.alpha] = alpha
        }

        let bitmap = RenderedBitmap(
            width: image.width,
            height: image.height,
            bytesPerRow: bytesPerRow,
            colorSpace: image.colorSpace,
            pixels: premultiplied
        )
        return try bitmap.pngData()
    }
}

extension ImageCodec {

    public static func cgImage(of image: ImageBuffer) throws -> CGImage {
        guard image.isWellFormed, !image.isEmpty else {
            throw RenderError(
                code: RenderError.encodingFailed,
                detail: "there is no picture to convert"
            )
        }

        let bytesPerRow = PixelFormat.bytesPerRow(width: image.width)
        guard
            let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: PixelFormat.bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: CoreGraphicsColorSpace.resolve(image.colorSpace),
                bitmapInfo: PixelFormat.bitmapInfo
            ), let data = context.data
        else {
            throw RenderError(
                code: RenderError.contextUnavailable,
                detail: "could not create a \(image.width)x\(image.height) context"
            )
        }

        let raw = UnsafeMutableRawBufferPointer(start: data, count: bytesPerRow * image.height)
        let channel = ImageBuffer.Channel.Offset.self
        for index in 0..<(image.width * image.height) {
            let source = index * ImageBuffer.Channel.count
            let destination = index * PixelFormat.bytesPerPixel
            let alpha = image.pixels[source + channel.alpha]

            func premultiply(_ value: UInt8) -> UInt8 {
                guard alpha < UInt8(PixelFormat.maximumChannelValue) else { return value }
                return UInt8(Int(value) * Int(alpha) / PixelFormat.maximumChannelValue)
            }

            raw[destination + PixelFormat.Offset.red] = premultiply(image.pixels[source + channel.red])
            raw[destination + PixelFormat.Offset.green] = premultiply(
                image.pixels[source + channel.green])
            raw[destination + PixelFormat.Offset.blue] = premultiply(
                image.pixels[source + channel.blue])
            raw[destination + PixelFormat.Offset.alpha] = alpha
        }

        guard let result = context.makeImage() else {
            throw RenderError(
                code: RenderError.encodingFailed,
                detail: "the context produced no image"
            )
        }
        return result
    }
}
