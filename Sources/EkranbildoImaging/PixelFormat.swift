import CoreGraphics

public enum PixelFormat {
    public static let bitsPerComponent = 8
    public static let componentsPerPixel = 4
    public static let bitsPerPixel = bitsPerComponent * componentsPerPixel
    public static let bytesPerPixel = componentsPerPixel
    public static let maximumChannelValue = 255

    public static let bitmapInfo =
        CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

    public enum Offset {
        public static let blue = 0
        public static let green = 1
        public static let red = 2
        public static let alpha = 3
    }

    public static func bytesPerRow(width: Int) -> Int { width * bytesPerPixel }
}
