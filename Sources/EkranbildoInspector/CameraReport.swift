import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability
import EkranbildoTimeline

public struct CameraReport: Sendable {

    public init() {}

    public func canonicalText(of path: CameraPath) -> String {
        path.keyframes
            .map {
                "\(CanonicalText.rounded($0.at.seconds, places: Precision.time))s \($0.view.canonicalText)"
            }
            .joined(separator: "\n")
    }

    public func html(of path: CameraPath, frame: SceneRect) -> String {
        let views = path.keyframes.enumerated()
            .map { index, keyframe in
                """
                <g class="view">\
                <rect x="\(number(keyframe.view.minX))" y="\(number(keyframe.view.minY))" \
                width="\(number(keyframe.view.raw.width))" \
                height="\(number(keyframe.view.raw.height))"/>\
                <text x="\(number(keyframe.view.minX + Layout.labelInset))" \
                y="\(number(keyframe.view.minY + Layout.labelBaseline))">\
                \(index) &#183; \(CanonicalText.rounded(keyframe.at.seconds, places: Precision.time))s\
                </text></g>
                """
            }
            .joined(separator: "\n")

        let travel = path.keyframes
            .map { "\(number($0.view.raw.center.x)),\(number($0.view.raw.center.y))" }
            .joined(separator: " ")

        return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <title>Ekranbildo camera path</title>
            <style>\(Self.styles)</style>
            </head>
            <body>
            <h1>Camera path</h1>
            <svg viewBox="0 0 \(number(frame.raw.width)) \(number(frame.raw.height))" \
            width="\(number(frame.raw.width))" height="\(number(frame.raw.height))">
            <rect class="frame" x="0" y="0" width="\(number(frame.raw.width))" \
            height="\(number(frame.raw.height))"/>
            <polyline class="travel" points="\(travel)"/>
            \(views)
            </svg>
            <pre>\(HTMLText.escaped(canonicalText(of: path)))</pre>
            </body>
            </html>
            """
    }

    private func number(_ value: Double) -> String {
        CanonicalText.rounded(value, places: Precision.places)
    }

    private enum Precision {
        static let places = 2
        static let time = 3
    }

    private enum Layout {
        static let labelInset: Double = 6
        static let labelBaseline: Double = 20
    }

    private static let styles = """
        :root { color-scheme: light dark; }
        body { font: 13px/1.5 ui-sans-serif, system-ui, sans-serif; margin: 24px; }
        h1 { font-size: 20px; }
        svg { max-width: 100%; height: auto; border: 1px solid #8884; }
        .frame { fill: #8881; stroke: #8886; }
        .view rect { fill: none; stroke: #2e86de; stroke-width: 3; }
        .view text { font: 14px ui-monospace, monospace; fill: #2e86de; }
        .travel { fill: none; stroke: #e91e63; stroke-width: 2; stroke-dasharray: 6 4; }
        pre { font: 12px ui-monospace, monospace; color: #666; }
        """
}
