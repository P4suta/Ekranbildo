import EkranbildoObservability
import Foundation

public struct Color: Hashable, Sendable, Codable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    public var opaque: Self {
        Self(red: red, green: green, blue: blue, alpha: 1)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decodeIfPresent(Double.self, forKey: .alpha) ?? Self.opaqueAlpha
        )
    }

    private static let opaqueAlpha: Double = 1

    private static func clamp(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return value < 0 ? 0 : (value > 1 ? 1 : value)
    }

    public var canonicalText: String {
        func channel(_ value: Double) -> String {
            let byte = UInt8((value * Double(HexChannel.maximumValue)).rounded())
            let hex = String(byte, radix: HexChannel.radix)
            return hex.count < HexChannel.digits ? "0" + hex : hex
        }
        return "#\(channel(red))\(channel(green))\(channel(blue))\(channel(alpha))"
    }
}

private enum HexChannel {
    static let maximumValue = 255
    static let radix = 16
    static let digits = 2
}

public struct GradientStop: Hashable, Sendable, Codable {
    public let location: Double
    public let color: Color

    public init(location: Double, color: Color) {
        self.location = location
        self.color = color
    }
}

public enum Paint: Hashable, Sendable, Codable {
    case solid(Color)
    case linearGradient(stops: [GradientStop], start: ScenePoint, end: ScenePoint)

    public var canonicalText: String {
        switch self {
        case .solid(let color):
            return color.canonicalText
        case .linearGradient(let stops, let start, let end):
            let rendered =
                stops
                .map { "\(DrawListFormat.number($0.location)) \($0.color.canonicalText)" }
                .joined(separator: ", ")
            return
                "linear(\(rendered)) from \(DrawListFormat.point(start)) to \(DrawListFormat.point(end))"
        }
    }
}

public enum LineCap: String, Hashable, Sendable, Codable {
    case butt
    case round
    case square
}

public enum LineJoin: String, Hashable, Sendable, Codable {
    case miter
    case round
    case bevel
}

public struct Stroke: Hashable, Sendable, Codable {
    public let paint: Paint
    public let width: Double
    public let cap: LineCap
    public let join: LineJoin
    public let miterLimit: Double
    public let dash: [Double]

    public init(
        paint: Paint,
        width: Double,
        cap: LineCap = .butt,
        join: LineJoin = .miter,
        miterLimit: Double = 10,
        dash: [Double] = []
    ) {
        self.paint = paint
        self.width = width
        self.cap = cap
        self.join = join
        self.miterLimit = miterLimit
        self.dash = dash
    }

    public var canonicalText: String {
        var text =
            "paint=\(paint.canonicalText) width=\(DrawListFormat.number(width))"
            + " cap=\(cap.rawValue) join=\(join.rawValue)"
            + " miter=\(DrawListFormat.number(miterLimit))"
        if !dash.isEmpty {
            text += " dash=[\(dash.map(DrawListFormat.number).joined(separator: " "))]"
        }
        return text
    }
}

public enum FontWeight: String, Hashable, Sendable, Codable {
    case regular
    case medium
    case semibold
    case bold
}

public struct FontSpec: Hashable, Sendable, Codable {
    public let family: String
    public let size: Double
    public let weight: FontWeight
    public let italic: Bool

    public init(family: String, size: Double, weight: FontWeight = .regular, italic: Bool = false) {
        self.family = family
        self.size = size
        self.weight = weight
        self.italic = italic
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            family: try container.decode(String.self, forKey: .family),
            size: try container.decode(Double.self, forKey: .size),
            weight: try container.decodeIfPresent(FontWeight.self, forKey: .weight) ?? .regular,
            italic: try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        )
    }

    public var canonicalText: String {
        let style = italic ? "\(weight.rawValue)-italic" : weight.rawValue
        return "[\(family) \(DrawListFormat.number(size)) \(style)]"
    }
}

public struct TextMetrics: Hashable, Sendable, Codable {
    public let width: Double
    public let ascent: Double
    public let descent: Double

    public init(width: Double, ascent: Double, descent: Double) {
        self.width = width
        self.ascent = ascent
        self.descent = descent
    }

    public var height: Double { ascent + descent }
}

public struct TextRun: Hashable, Sendable, Codable {
    public let text: String
    public let font: FontSpec
    public let baselineOrigin: ScenePoint
    public let paint: Paint
    public let metrics: TextMetrics

    public init(
        text: String,
        font: FontSpec,
        baselineOrigin: ScenePoint,
        paint: Paint,
        metrics: TextMetrics
    ) {
        self.text = text
        self.font = font
        self.baselineOrigin = baselineOrigin
        self.paint = paint
        self.metrics = metrics
    }

    public var bounds: SceneRect {
        SceneRect(
            x: baselineOrigin.x,
            y: baselineOrigin.y - metrics.ascent,
            width: metrics.width,
            height: metrics.height
        )
    }
}

public struct Shadow: Hashable, Sendable, Codable {
    public let blur: Double
    public let offset: ScenePoint
    public let color: Color

    public init(blur: Double, offset: ScenePoint, color: Color) {
        self.blur = max(0, blur)
        self.offset = offset
        self.color = color
    }

    public var canonicalText: String {
        "blur=\(DrawListFormat.number(blur)) "
            + "offset=\(DrawListFormat.point(offset)) "
            + "color=\(color.canonicalText)"
    }
}

public struct ImageRef: Hashable, Sendable, Codable {
    public let contentHash: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(contentHash: String, pixelWidth: Int, pixelHeight: Int) {
        self.contentHash = contentHash
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

enum DrawListFormat {
    static let places = 3

    static func number(_ value: Double) -> String {
        CanonicalText.rounded(value, places: places)
    }

    static func point<Space>(_ point: SpacePoint<Space>) -> String {
        "[\(number(point.x)) \(number(point.y))]"
    }

    static func rect<Space>(_ rect: SpaceRect<Space>) -> String {
        "[\(number(rect.minX)) \(number(rect.minY)) \(number(rect.width)) \(number(rect.height))]"
    }
}
