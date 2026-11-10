import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability
import Foundation

public struct DetectionReport: Sendable {

    public init() {}

    public func html(
        elements: [ScreenElement],
        image: [UInt8],
        width: Int,
        height: Int,
        ladder: [SceneRect] = []
    ) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>Ekranbildo detection</title>
        <style>\(Self.styles)</style>
        </head>
        <body>
        <h1>Detection</h1>
        \(overlay(elements: elements, image: image, width: width, height: height, ladder: ladder))
        \(table(elements))
        </body>
        </html>
        """
    }

    private func overlay(
        elements: [ScreenElement],
        image: [UInt8],
        width: Int,
        height: Int,
        ladder: [SceneRect]
    ) -> String {
        let boxes = elements.enumerated()
            .map { index, element in
                let rect = element.rect.raw
                return """
                    <g class="element \(element.kind.rawValue)">\
                    <rect x="\(number(rect.minX))" y="\(number(rect.minY))" \
                    width="\(number(rect.width))" height="\(number(rect.height))"/>\
                    <text x="\(number(rect.minX + Layout.labelInset))" \
                    y="\(number(rect.minY + Layout.labelBaseline))">\(index)</text>\
                    </g>
                    """
            }
            .joined(separator: "\n")

        let rungs = ladder.enumerated()
            .map { index, rect in
                """
                <rect class="rung" x="\(number(rect.minX))" y="\(number(rect.minY))" \
                width="\(number(rect.raw.width))" height="\(number(rect.raw.height))" \
                stroke-dasharray="\(Layout.rungDash * Double(index + 1))"/>
                """
            }
            .joined(separator: "\n")

        return """
            <svg viewBox="0 0 \(width) \(height)" width="\(width)" height="\(height)">
            <image x="0" y="0" width="\(width)" height="\(height)" href="\(dataURI(image))"/>
            \(boxes)
            \(rungs)
            </svg>
            """
    }

    private func table(_ elements: [ScreenElement]) -> String {
        guard !elements.isEmpty else { return "<p class=\"empty\">Nothing was detected.</p>" }
        let rows = elements.enumerated()
            .map { index, element in
                """
                <tr><td>\(index)</td>\
                <td>\(HTMLText.escaped(element.canonicalText))</td>\
                <td>\(number(element.rect.raw.area))</td></tr>
                """
            }
            .joined(separator: "\n")
        return """
            <table>
            <tr><th>#</th><th>element</th><th>area</th></tr>
            \(rows)
            </table>
            """
    }

    private func dataURI(_ png: [UInt8]) -> String {
        "data:image/png;base64,\(Data(png).base64EncodedString())"
    }

    private func number(_ value: Double) -> String {
        CanonicalText.rounded(value, places: Layout.places)
    }

    private enum Layout {
        static let places = 2
        static let labelInset: Double = 3
        static let labelBaseline: Double = 11
        static let rungDash: Double = 4
    }

    private static let styles = """
        :root { color-scheme: light dark; }
        body { font: 13px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 24px; }
        h1 { font-size: 20px; }
        svg { max-width: 100%; height: auto; border: 1px solid #8884; }
        .element rect { fill: none; stroke-width: 1; }
        .element text { font: 9px ui-monospace, monospace; }
        .surface rect { stroke: #2e86de; } .surface text { fill: #2e86de; }
        .text rect { stroke: #e67e22; } .text text { fill: #e67e22; }
        .canvas rect { stroke: #7f8c8d; } .canvas text { fill: #7f8c8d; }
        .rung { fill: none; stroke: #e91e63; stroke-width: 2; }
        table { border-collapse: collapse; font-variant-numeric: tabular-nums; margin-top: 16px; }
        th, td { padding: 2px 8px; text-align: right; border-bottom: 1px solid #8882; }
        th { text-align: left; }
        .empty { color: #666; }
        """
}
