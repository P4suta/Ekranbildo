import EkranbildoContracts
import EkranbildoGeometry

public struct MagnifiedView: Hashable, Sendable {
    public let area: ScreenRect
    public let across: Int
    public let pixels: [ImageBuffer.Pixel]

    public var centre: ImageBuffer.Pixel {
        let middle = Geo.middleIndex(of: across)
        let index = middle * across + middle
        guard pixels.indices.contains(index) else {
            return ImageBuffer.Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return pixels[index]
    }
}

public struct Magnifier: Sendable {
    public let across: Int

    public init(across: Int = Defaults.across) {
        let wanted = max(Defaults.smallest, across)
        self.across = wanted.isMultiple(of: Parity.even) ? wanted + 1 : wanted
    }

    public enum Defaults {
        public static let across = 15
        public static let smallest = 3
    }

    private enum Parity {
        static let even = 2
    }

    public func look(at point: ScreenPoint, in frozen: FrozenScreen) -> MagnifiedView {
        let radius = Geo.middleIndex(of: across)
        let originX = Int(point.x.rounded()) - radius
        let originY = Int(point.y.rounded()) - radius

        var pixels: [ImageBuffer.Pixel] = []
        pixels.reserveCapacity(across * across)
        for row in 0..<across {
            for column in 0..<across {
                let x = originX + column
                let y = originY + row
                let inside =
                    x >= 0 && y >= 0 && x < frozen.image.width && y < frozen.image.height
                pixels.append(inside ? frozen.image[x: x, y: y] : Self.nothing)
            }
        }

        return MagnifiedView(
            area: ScreenRect(
                x: Double(originX),
                y: Double(originY),
                width: Double(across),
                height: Double(across)
            ),
            across: across,
            pixels: pixels
        )
    }

    public static func hex(of pixel: ImageBuffer.Pixel) -> String {
        "#" + [pixel.red, pixel.green, pixel.blue].map(twoDigits).joined()
    }

    private static func twoDigits(_ value: UInt8) -> String {
        let text = String(value, radix: Hex.radix, uppercase: true)
        let missing = Hex.digitsPerChannel - text.count
        guard missing > 0 else { return text }
        return String(repeating: "0", count: missing) + text
    }

    private static let nothing = ImageBuffer.Pixel(red: 0, green: 0, blue: 0, alpha: 0)

    private enum Hex {
        static let radix = 16
        static let digitsPerChannel = 2
    }
}
