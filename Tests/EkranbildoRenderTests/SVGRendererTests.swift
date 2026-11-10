import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("SVGRenderer")
struct SVGRendererTests {
    private let black = Paint.solid(Color(red: 0, green: 0, blue: 0, alpha: 1))
    private let canvas = SceneRect(x: 0, y: 0, width: 200, height: 100)

    private func render(_ commands: [DrawCommand], renderer: SVGRenderer = SVGRenderer()) -> String {
        renderer.render(DrawList(canvas: canvas, colorSpace: .sRGB, commands: commands))
    }

    @Test("An empty list still produces a well-formed document")
    func emptyDocument() {
        let svg = render([])
        #expect(svg.hasPrefix("<svg"))
        #expect(svg.hasSuffix("</svg>"))
        #expect(svg.contains("viewBox=\"0 0 200 100\""))
        #expect(svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
    }

    @Test("A fill becomes a path with no stroke")
    func fillCommand() {
        let svg = render([.fill(Path.rect(SceneRect(x: 10, y: 20, width: 30, height: 40)), black)])
        #expect(svg.contains("<path d=\"M 10 20 L 40 20 L 40 60 L 10 60 Z\""))
        #expect(svg.contains("fill=\"#000000\""))
        #expect(svg.contains("stroke=\"none\""))
    }

    @Test("A stroke carries its width, cap and join")
    func strokeCommand() {
        let stroke = Stroke(paint: black, width: 2.5, cap: .round, join: .bevel, dash: [4, 2])
        let svg = render([
            .stroke(Path.polyline(Polyline(points: [P2(x: 0, y: 0), P2(x: 10, y: 10)])), stroke)
        ])
        #expect(svg.contains("stroke-width=\"2.5\""))
        #expect(svg.contains("stroke-linecap=\"round\""))
        #expect(svg.contains("stroke-linejoin=\"bevel\""))
        #expect(svg.contains("stroke-dasharray=\"4 2\""))
        #expect(svg.contains("fill=\"none\""))
    }

    @Test("Partial alpha becomes a separate opacity attribute")
    func alphaHandling() {
        let translucent = Paint.solid(Color(red: 1, green: 0, blue: 0, alpha: 0.5))
        let svg = render([.fill(Path.rect(canvas), translucent)])
        #expect(svg.contains("fill=\"#ff0000\""))
        #expect(svg.contains("fill-opacity=\"0.5\""))
        #expect(!svg.contains("fill-opacity=\"1\""))
    }

    @Test("Text is placed on its baseline with the font it was measured in")
    func textCommand() {
        let run = TextRun(
            text: "Save",
            font: FontSpec(family: "Inter", size: 14, weight: .semibold),
            baselineOrigin: ScenePoint(x: 12, y: 30),
            paint: black,
            metrics: TextMetrics(width: 28, ascent: 11, descent: 3)
        )
        let svg = render([.text(run)])
        #expect(svg.contains("<text x=\"12\" y=\"30\""))
        #expect(svg.contains("font-family=\"Inter\""))
        #expect(svg.contains("font-size=\"14\""))
        #expect(svg.contains("font-weight=\"600\""))
        #expect(svg.contains(">Save</text>"))
    }

    @Test("Text content is XML escaped")
    func textEscaping() {
        let run = TextRun(
            text: "<a> & \"b\"",
            font: FontSpec(family: "Inter", size: 10),
            baselineOrigin: ScenePoint(x: 0, y: 0),
            paint: black,
            metrics: TextMetrics(width: 10, ascent: 8, descent: 2)
        )
        let svg = render([.text(run)])
        #expect(svg.contains(">&lt;a&gt; &amp; &quot;b&quot;</text>"))
    }

    @Test("A gradient becomes a definition referenced by the shape")
    func gradientFill() {
        let paint = Paint.linearGradient(
            stops: [
                GradientStop(location: 0, color: Color(red: 1, green: 1, blue: 1, alpha: 1)),
                GradientStop(location: 1, color: Color(red: 0, green: 0, blue: 0, alpha: 1)),
            ],
            start: ScenePoint(x: 0, y: 0),
            end: ScenePoint(x: 0, y: 100)
        )
        let svg = render([.fill(Path.rect(canvas), paint)])
        #expect(svg.contains("<linearGradient id=\"gradient0\""))
        #expect(svg.contains("fill=\"url(#gradient0)\""))
        #expect(svg.contains("<stop offset=\"0\""))
        #expect(svg.contains("<stop offset=\"1\""))
    }

    @Test("An image is omitted unless the renderer can resolve a reference for it")
    func imageWithoutResolver() {
        let image = ImageRef(contentHash: "abc", pixelWidth: 10, pixelHeight: 10)
        let svg = render([.image(image, canvas, opacity: 1, cornerRadius: 0)])
        #expect(!svg.contains("<image"))
    }

    @Test("An image is emitted when a reference can be resolved")
    func imageWithResolver() {
        let image = ImageRef(contentHash: "abc", pixelWidth: 10, pixelHeight: 10)
        let renderer = SVGRenderer(imageHref: { "assets/\($0.contentHash).png" })
        let svg = render([.image(image, canvas, opacity: 1, cornerRadius: 0)], renderer: renderer)
        #expect(svg.contains("<image href=\"assets/abc.png\""))
        #expect(svg.contains("width=\"200\" height=\"100\""))
    }

    @Test("Curves are emitted with their control points")
    func curveCommand() {
        let path = Path(elements: [
            .move(ScenePoint(x: 0, y: 0)),
            .quadCurve(to: ScenePoint(x: 10, y: 0), control: ScenePoint(x: 5, y: 10)),
            .cubicCurve(
                to: ScenePoint(x: 20, y: 0),
                control1: ScenePoint(x: 12, y: 5),
                control2: ScenePoint(x: 18, y: 5)
            ),
        ])
        let svg = render([.fill(path, black)])
        #expect(svg.contains("Q 5 10 10 0"))
        #expect(svg.contains("C 12 5 18 5 20 0"))
    }

    @Test("The same draw list always produces the same document")
    func reproducible() {
        let commands: [DrawCommand] = [.fill(Path.rect(canvas), black)]
        #expect(isReproducible { render(commands) })
    }
}
