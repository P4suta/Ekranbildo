import EkranbildoContracts
import EkranbildoObservability

public struct SVGRenderer: Sendable {
    private let imageHref: @Sendable (ImageRef) -> String?

    public init(imageHref: @escaping @Sendable (ImageRef) -> String? = { _ in nil }) {
        self.imageHref = imageHref
    }

    public func render(_ list: DrawList) -> String {
        var gradients: [String] = []
        var filters: [String] = []
        var body: [String] = []

        for command in list.commands {
            switch command {
            case .fill(let path, let paint):
                let reference = Self.paintReference(paint, index: gradients.count, into: &gradients)
                body.append(
                    "<path d=\"\(Self.pathData(path))\" fill=\(reference.fillAttribute) stroke=\"none\"/>"
                )

            case .stroke(let path, let stroke):
                let reference = Self.paintReference(
                    stroke.paint, index: gradients.count, into: &gradients)
                var attributes = [
                    "d=\"\(Self.pathData(path))\"",
                    "fill=\"none\"",
                    "stroke=\(reference.strokeAttribute)",
                    "stroke-width=\"\(Self.number(stroke.width))\"",
                    "stroke-linecap=\"\(stroke.cap.rawValue)\"",
                    "stroke-linejoin=\"\(stroke.join.rawValue)\"",
                ]
                if !stroke.dash.isEmpty {
                    let pattern = stroke.dash.map(Self.number).joined(separator: " ")
                    attributes.append("stroke-dasharray=\"\(pattern)\"")
                }
                body.append("<path \(attributes.joined(separator: " "))/>")

            case .text(let run):
                let reference = Self.paintReference(run.paint, index: gradients.count, into: &gradients)
                body.append(
                    "<text x=\"\(Self.number(run.baselineOrigin.x))\" "
                        + "y=\"\(Self.number(run.baselineOrigin.y))\" "
                        + "font-family=\"\(Self.escaped(run.font.family))\" "
                        + "font-size=\"\(Self.number(run.font.size))\" "
                        + "font-weight=\"\(Self.weight(run.font.weight))\" "
                        + "fill=\(reference.fillAttribute)"
                        + ">\(Self.escaped(run.text))</text>"
                )

            case .image(let ref, let rect, let opacity, let cornerRadius):
                guard let href = imageHref(ref) else { continue }
                var attributes = [
                    "href=\"\(Self.escaped(href))\"",
                    "x=\"\(Self.number(rect.minX))\"",
                    "y=\"\(Self.number(rect.minY))\"",
                    "width=\"\(Self.number(rect.width))\"",
                    "height=\"\(Self.number(rect.height))\"",
                    "opacity=\"\(Self.number(opacity))\"",
                ]
                if cornerRadius > 0 {
                    let name = "clip\(filters.count)"
                    filters.append(
                        "<clipPath id=\"\(name)\"><path d=\""
                            + "\(Self.pathData(Path.roundedRect(rect, radius: cornerRadius)))"
                            + "\"/></clipPath>"
                    )
                    attributes.append("clip-path=\"url(#\(name))\"")
                }
                body.append("<image \(attributes.joined(separator: " "))/>")

            case .shadow(let path, let shadow):
                let name = "shadow\(filters.count)"
                filters.append(
                    "<filter id=\"\(name)\" x=\"-50%\" y=\"-50%\" width=\"200%\" height=\"200%\">"
                        + "<feDropShadow dx=\"\(Self.number(shadow.offset.x))\" "
                        + "dy=\"\(Self.number(shadow.offset.y))\" "
                        + "stdDeviation=\"\(Self.number(shadow.blur / Filters.blurToDeviation))\" "
                        + "flood-color=\"\(Self.hex(shadow.color))\" "
                        + "flood-opacity=\"\(Self.number(shadow.color.alpha))\"/>"
                        + "</filter>"
                )
                body.append(
                    "<path d=\"\(Self.pathData(path))\" fill=\"\(Self.hex(shadow.color))\" "
                        + "filter=\"url(#\(name))\"/>"
                )
            }
        }

        let canvas = list.canvas
        var lines = [
            "<svg xmlns=\"http://www.w3.org/2000/svg\" "
                + "width=\"\(Self.number(canvas.width))\" height=\"\(Self.number(canvas.height))\" "
                + "viewBox=\"\(Self.number(canvas.minX)) \(Self.number(canvas.minY)) "
                + "\(Self.number(canvas.width)) \(Self.number(canvas.height))\">"
        ]
        if !gradients.isEmpty || !filters.isEmpty {
            lines.append("<defs>")
            lines.append(contentsOf: gradients)
            lines.append(contentsOf: filters)
            lines.append("</defs>")
        }
        lines.append(contentsOf: body)
        lines.append("</svg>")
        return lines.joined(separator: "\n")
    }

    private struct PaintReference {
        let value: String
        let opacity: Double

        var fillAttribute: String { attribute(named: "fill") }
        var strokeAttribute: String { attribute(named: "stroke") }

        private func attribute(named name: String) -> String {
            opacity >= 1
                ? "\"\(value)\""
                : "\"\(value)\" \(name)-opacity=\"\(SVGRenderer.number(opacity))\""
        }
    }

    private static func paintReference(
        _ paint: Paint,
        index: Int,
        into gradients: inout [String]
    ) -> PaintReference {
        switch paint {
        case .solid(let color):
            return PaintReference(value: hex(color), opacity: color.alpha)

        case .linearGradient(let stops, let start, let end):
            let identifier = "gradient\(index)"
            var definition =
                "<linearGradient id=\"\(identifier)\" gradientUnits=\"userSpaceOnUse\" "
                + "x1=\"\(number(start.x))\" y1=\"\(number(start.y))\" "
                + "x2=\"\(number(end.x))\" y2=\"\(number(end.y))\">"
            for stop in stops {
                definition +=
                    "<stop offset=\"\(number(stop.location))\" "
                    + "stop-color=\"\(hex(stop.color))\" "
                    + "stop-opacity=\"\(number(stop.color.alpha))\"/>"
            }
            definition += "</linearGradient>"
            gradients.append(definition)
            return PaintReference(value: "url(#\(identifier))", opacity: 1)
        }
    }

    private enum Filters {
        static let blurToDeviation: Double = 2
    }

    private static func hex(_ color: Color) -> String {
        String(color.canonicalText.dropLast(alphaDigits))
    }

    private static let alphaDigits = 2

    private static func weight(_ weight: FontWeight) -> String {
        switch weight {
        case .regular: "400"
        case .medium: "500"
        case .semibold: "600"
        case .bold: "700"
        }
    }

    private static func pathData(_ path: Path) -> String {
        path.elements.map { element in
            switch element {
            case .move(let point):
                "M \(number(point.x)) \(number(point.y))"
            case .line(let point):
                "L \(number(point.x)) \(number(point.y))"
            case .quadCurve(let to, let control):
                "Q \(number(control.x)) \(number(control.y)) \(number(to.x)) \(number(to.y))"
            case .cubicCurve(let to, let control1, let control2):
                "C \(number(control1.x)) \(number(control1.y)) "
                    + "\(number(control2.x)) \(number(control2.y)) "
                    + "\(number(to.x)) \(number(to.y))"
            case .close:
                "Z"
            }
        }
        .joined(separator: " ")
    }

    static let precisionPlaces = 3

    public static func number(_ value: Double) -> String {
        let rounded = CanonicalText.rounded(value, places: precisionPlaces)
        guard rounded.contains(".") else { return rounded }
        var trimmed = rounded
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed
    }

    static func escaped(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(character)
            }
        }
        return result
    }
}
