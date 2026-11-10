public struct ImageBuffer: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public let colorSpace: CanonicalColorSpace
    public let pixels: [UInt8]

    public init(width: Int, height: Int, colorSpace: CanonicalColorSpace, pixels: [UInt8]) {
        self.width = max(0, width)
        self.height = max(0, height)
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

        public static let transparent = Self(red: 0, green: 0, blue: 0, alpha: 0)

        public var luminance: Double {
            (Double(red) * Weights.red + Double(green) * Weights.green + Double(blue) * Weights.blue)
                / Double(Channel.maximum)
        }

        private enum Weights {
            static let red = 0.2126
            static let green = 0.7152
            static let blue = 0.0722
        }
    }

    public enum Channel {
        public static let count = 4
        public static let maximum = 255
        public enum Offset {
            public static let red = 0
            public static let green = 1
            public static let blue = 2
            public static let alpha = 3
        }
    }

    public var pixelCount: Int { width * height }
    public var isEmpty: Bool { pixelCount == 0 }

    public var isWellFormed: Bool { pixels.count >= pixelCount * Channel.count }

    public var bounds: SceneRect {
        SceneRect(x: 0, y: 0, width: Double(width), height: Double(height))
    }

    public subscript(x column: Int, y row: Int) -> Pixel {
        guard isWellFormed, !isEmpty else { return .transparent }
        let clampedColumn = min(max(column, 0), width - 1)
        let clampedRow = min(max(row, 0), height - 1)
        let offset = (clampedRow * width + clampedColumn) * Channel.count
        return Pixel(
            red: pixels[offset + Channel.Offset.red],
            green: pixels[offset + Channel.Offset.green],
            blue: pixels[offset + Channel.Offset.blue],
            alpha: pixels[offset + Channel.Offset.alpha]
        )
    }
}

extension ImageBuffer {
    public func cropped(to rect: ImageRect) -> ImageBuffer? {
        let left = Int(rect.minX.rounded())
        let top = Int(rect.minY.rounded())
        let wide = Int(rect.width.rounded())
        let tall = Int(rect.height.rounded())

        guard wide > 0, tall > 0 else { return nil }
        guard left >= 0, top >= 0, left + wide <= width, top + tall <= height else { return nil }

        var taken: [UInt8] = []
        taken.reserveCapacity(wide * tall * Channels.count)
        for y in top..<(top + tall) {
            let start = (y * width + left) * Channels.count
            taken.append(contentsOf: pixels[start..<(start + wide * Channels.count)])
        }
        return ImageBuffer(
            width: wide, height: tall, colorSpace: colorSpace, pixels: taken)
    }

    private enum Channels {
        static let count = 4
    }
}
