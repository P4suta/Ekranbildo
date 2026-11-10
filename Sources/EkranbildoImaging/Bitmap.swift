import CoreGraphics
import EkranbildoContracts
import EkranbildoObservability

public struct RenderedBitmap: Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let colorSpace: CanonicalColorSpace
    public let pixels: [UInt8]

    public init(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        colorSpace: CanonicalColorSpace,
        pixels: [UInt8]
    ) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.colorSpace = colorSpace
        self.pixels = pixels
    }

    public struct Pixel: Hashable, Sendable {
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public let alpha: UInt8

        public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }
    }

    public var imageBuffer: ImageBuffer {
        var bytes = [UInt8](repeating: 0, count: width * height * ImageBuffer.Channel.count)
        let channel = ImageBuffer.Channel.Offset.self
        for row in 0..<height {
            for column in 0..<width {
                let source = pixel(x: column, y: row)
                let offset = (row * width + column) * ImageBuffer.Channel.count
                bytes[offset + channel.red] = source.red
                bytes[offset + channel.green] = source.green
                bytes[offset + channel.blue] = source.blue
                bytes[offset + channel.alpha] = source.alpha
            }
        }
        return ImageBuffer(
            width: width, height: height, colorSpace: colorSpace, pixels: bytes)
    }

    public func pixel(x: Int, y: Int) -> Pixel {
        guard x >= 0, y >= 0, x < width, y < height else {
            return Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        }
        let offset = y * bytesPerRow + x * PixelFormat.bytesPerPixel
        let alpha = pixels[offset + PixelFormat.Offset.alpha]
        let blue = pixels[offset + PixelFormat.Offset.blue]
        let green = pixels[offset + PixelFormat.Offset.green]
        let red = pixels[offset + PixelFormat.Offset.red]
        guard alpha > 0, alpha < UInt8(PixelFormat.maximumChannelValue) else {
            return Pixel(red: red, green: green, blue: blue, alpha: alpha)
        }
        func straighten(_ value: UInt8) -> UInt8 {
            let full = Double(PixelFormat.maximumChannelValue)
            return UInt8(min(PixelFormat.maximumChannelValue, Int(Double(value) * full / Double(alpha))))
        }
        return Pixel(
            red: straighten(red),
            green: straighten(green),
            blue: straighten(blue),
            alpha: alpha
        )
    }
}

public struct RenderWarning: Hashable, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let fontSubstituted: DiagnosticCode = 210
    public static let imageUnresolved: DiagnosticCode = 211
}

public struct RenderResult: Sendable {
    public let bitmap: RenderedBitmap
    public let warnings: [RenderWarning]

    public init(bitmap: RenderedBitmap, warnings: [RenderWarning]) {
        self.bitmap = bitmap
        self.warnings = warnings
    }
}

public struct RenderError: Error, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let contextUnavailable: DiagnosticCode = 200
    public static let encodingFailed: DiagnosticCode = 201
    public static let undecodableImage: DiagnosticCode = 202
}
