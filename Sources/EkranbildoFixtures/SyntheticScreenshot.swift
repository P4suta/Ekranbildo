import EkranbildoContracts

public struct SyntheticScreenshot: Sendable {
    public private(set) var width: Int
    public private(set) var height: Int
    private var pixels: [UInt8]
    public private(set) var regions: [Region] = []

    public struct Region: Hashable, Sendable {
        public let rect: SceneRect
        public let name: String
    }

    public init(
        width: Int,
        height: Int,
        background: ImageBuffer.Pixel = Defaults.background
    ) {
        self.width = max(0, width)
        self.height = max(0, height)
        pixels = [UInt8](repeating: 0, count: self.width * self.height * ImageBuffer.Channel.count)
        fill(SceneRect(x: 0, y: 0, width: Double(self.width), height: Double(self.height)), with: background)
    }

    public enum Defaults {
        private static let offWhite = (red: UInt8(245), green: UInt8(245), blue: UInt8(247))

        public static let background = ImageBuffer.Pixel.opaque(
            red: offWhite.red, green: offWhite.green, blue: offWhite.blue)
    }

    @discardableResult
    public mutating func add(
        _ rect: SceneRect,
        color: ImageBuffer.Pixel,
        named name: String
    ) -> Self {
        fill(rect, with: color)
        regions.append(Region(rect: rect, name: name))
        return self
    }

    public mutating func paint(_ rect: SceneRect, color: ImageBuffer.Pixel) {
        fill(rect, with: color)
    }

    private mutating func fill(_ rect: SceneRect, with color: ImageBuffer.Pixel) {
        let minX = max(0, Int(rect.minX.rounded(.down)))
        let minY = max(0, Int(rect.minY.rounded(.down)))
        let maxX = min(width, Int(rect.maxX.rounded(.up)))
        let maxY = min(height, Int(rect.maxY.rounded(.up)))
        guard minX < maxX, minY < maxY else { return }

        for row in minY..<maxY {
            for column in minX..<maxX {
                let offset = (row * width + column) * ImageBuffer.Channel.count
                let channel = ImageBuffer.Channel.Offset.self
                pixels[offset + channel.red] = color.red
                pixels[offset + channel.green] = color.green
                pixels[offset + channel.blue] = color.blue
                pixels[offset + channel.alpha] = color.alpha
            }
        }
    }

    public var image: ImageBuffer {
        ImageBuffer(width: width, height: height, colorSpace: .sRGB, pixels: pixels)
    }

    public func region(named name: String) -> SceneRect? {
        regions.first { $0.name == name }?.rect
    }
}

extension ImageBuffer.Pixel {
    public static func opaque(red: UInt8, green: UInt8, blue: UInt8) -> Self {
        Self(red: red, green: green, blue: blue, alpha: UInt8(ImageBuffer.Channel.maximum))
    }
}
