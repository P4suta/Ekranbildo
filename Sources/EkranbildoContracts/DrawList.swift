import EkranbildoGeometry
import EkranbildoObservability

public enum DrawCommand: Hashable, Sendable, Codable {
    case fill(Path, Paint)
    case stroke(Path, Stroke)
    case text(TextRun)
    case image(ImageRef, SceneRect, opacity: Double, cornerRadius: Double)
    case shadow(Path, Shadow)

    public static func bounds(of commands: [Self]) -> SceneRect? {
        var union: Rect?
        for command in commands {
            guard let commandBounds = command.bounds?.raw else { continue }
            guard let current = union else {
                union = commandBounds
                continue
            }
            let minX = min(current.minX, commandBounds.minX)
            let minY = min(current.minY, commandBounds.minY)
            let maxX = max(current.maxX, commandBounds.maxX)
            let maxY = max(current.maxY, commandBounds.maxY)
            union = Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        return union.map(SceneRect.init)
    }

    public var bounds: SceneRect? {
        switch self {
        case .fill(let path, _):
            return path.bounds
        case .stroke(let path, let stroke):
            guard let pathBounds = path.bounds else { return nil }
            return SpaceRect(pathBounds.raw.inset(by: -Geo.half(stroke.width)))
        case .text(let run):
            return run.bounds
        case .shadow(let path, let shadow):
            guard let pathBounds = path.bounds else { return nil }
            let spread = pathBounds.raw.inset(by: -shadow.blur)
            return SceneRect(
                x: spread.minX + min(0, shadow.offset.x),
                y: spread.minY + min(0, shadow.offset.y),
                width: spread.width + abs(shadow.offset.x),
                height: spread.height + abs(shadow.offset.y)
            )
        case .image(_, let rect, _, _):
            return rect
        }
    }

    var canonicalText: String {
        switch self {
        case .fill(let path, let paint):
            return "fill paint=\(paint.canonicalText) path=\(path.canonicalText)"
        case .stroke(let path, let stroke):
            return "stroke \(stroke.canonicalText) path=\(path.canonicalText)"
        case .text(let run):
            return
                "text \(CanonicalText.quoted(run.text)) font=\(run.font.canonicalText) "
                + "baseline=\(DrawListFormat.point(run.baselineOrigin)) "
                + "paint=\(run.paint.canonicalText) "
                + "metrics=[w \(DrawListFormat.number(run.metrics.width)) "
                + "a \(DrawListFormat.number(run.metrics.ascent)) "
                + "d \(DrawListFormat.number(run.metrics.descent))]"
        case .image(let ref, let rect, let opacity, let cornerRadius):
            return
                "image \(ref.contentHash) rect=\(DrawListFormat.rect(rect)) "
                + "opacity=\(DrawListFormat.number(opacity)) "
                + "corner=\(DrawListFormat.number(cornerRadius))"
        case .shadow(let path, let shadow):
            return "shadow \(shadow.canonicalText) path=\(path.canonicalText)"
        }
    }
}

public enum CanonicalColorSpace: String, Hashable, Sendable, Codable {
    case displayP3
    case sRGB
    case extendedLinearDisplayP3

    public static let workingSpace = Self.displayP3
}

public struct DrawList: Hashable, Sendable, Codable {
    public let canvas: SceneRect
    public let colorSpace: CanonicalColorSpace
    public let commands: [DrawCommand]

    public init(canvas: SceneRect, colorSpace: CanonicalColorSpace, commands: [DrawCommand]) {
        self.canvas = canvas
        self.colorSpace = colorSpace
        self.commands = commands
    }

    public var bounds: SceneRect? { DrawCommand.bounds(of: commands) }

    public var canonicalText: String {
        let header =
            "drawlist canvas=\(DrawListFormat.rect(canvas)) "
            + "colorspace=\(colorSpace.rawValue) commands=\(commands.count)"
        let lines = commands.enumerated().map { index, command in
            "\(index) \(command.canonicalText)"
        }
        return ([header] + lines).joined(separator: "\n")
    }
}
