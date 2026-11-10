@testable import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Colour and paint")
struct ColorTests {

    @Test("Components are clamped into range")
    func clamping() {
        let color = Color(red: 1.5, green: -0.2, blue: 0.5, alpha: 2)
        #expect(color.red == 1)
        #expect(color.green == 0)
        #expect(color.blue == 0.5)
        #expect(color.alpha == 1)
    }

    @Test("Colours render as eight-bit hex so goldens stay readable")
    func hexRendering() {
        #expect(Color(red: 1, green: 0, blue: 0, alpha: 1).canonicalText == "#ff0000ff")
        #expect(Color(red: 0, green: 0, blue: 0, alpha: 0).canonicalText == "#00000000")
        #expect(Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 1).canonicalText == "#808080ff")
    }

    @Test("A solid paint renders as its colour")
    func solidPaint() {
        #expect(Paint.solid(.init(red: 0, green: 0, blue: 0, alpha: 1)).canonicalText == "#000000ff")
    }

    @Test("A gradient renders its stops in order")
    func gradientPaint() {
        let paint = Paint.linearGradient(
            stops: [
                GradientStop(location: 0, color: Color(red: 1, green: 1, blue: 1, alpha: 1)),
                GradientStop(location: 1, color: Color(red: 0, green: 0, blue: 0, alpha: 1)),
            ],
            start: ScenePoint(x: 0, y: 0),
            end: ScenePoint(x: 0, y: 100)
        )
        #expect(
            paint.canonicalText
                == "linear(0.000 #ffffffff, 1.000 #000000ff) from [0.000 0.000] to [0.000 100.000]"
        )
    }
}

@Suite("Path")
struct PathTests {

    @Test("A rectangle is four corners and a close")
    func rectangle() {
        let path = Path.rect(SceneRect(x: 10, y: 20, width: 30, height: 40))
        #expect(path.elements.count == 5)
        #expect(path.elements.first == .move(ScenePoint(x: 10, y: 20)))
        #expect(path.elements.last == .close)
    }

    @Test("A polyline is a move followed by lines and is left open")
    func polyline() {
        let path = Path.polyline(Polyline(points: [P2(x: 0, y: 0), P2(x: 1, y: 1), P2(x: 2, y: 0)]))
        #expect(path.elements.count == 3)
        #expect(path.elements[0] == .move(ScenePoint(x: 0, y: 0)))
        #expect(path.elements[2] == .line(ScenePoint(x: 2, y: 0)))
    }

    @Test("An empty polyline produces an empty path")
    func emptyPolyline() {
        #expect(Path.polyline(Polyline(points: [])).elements.isEmpty)
        #expect(Path.polyline(Polyline(points: [])).isEmpty)
    }

    @Test("Path bounds cover every point, including curve control points")
    func bounds() {
        let path = Path(elements: [
            .move(ScenePoint(x: 0, y: 0)),
            .cubicCurve(
                to: ScenePoint(x: 10, y: 0),
                control1: ScenePoint(x: 3, y: -20),
                control2: ScenePoint(x: 7, y: 20)
            ),
        ])
        let bounds = path.bounds
        #expect(bounds?.minY == -20)
        #expect(bounds?.maxY == 20)
        #expect(bounds?.minX == 0)
        #expect(bounds?.maxX == 10)
    }

    @Test("An empty path has no bounds")
    func emptyBounds() {
        #expect(Path(elements: []).bounds == nil)
    }

    @Test("A rounded rectangle stays within the rectangle it rounds")
    func roundedRectangleBounds() {
        let rect = SceneRect(x: 0, y: 0, width: 100, height: 50)
        let path = Path.roundedRect(rect, cornerRadius: 12)
        let bounds = path.bounds
        #expect(bounds?.minX == 0)
        #expect(bounds?.minY == 0)
        #expect(bounds?.maxX == 100)
        #expect(bounds?.maxY == 50)
    }

    @Test("A corner radius larger than half the shorter side is clamped")
    func cornerRadiusClamping() {
        let rect = SceneRect(x: 0, y: 0, width: 20, height: 10)
        let clamped = Path.roundedRect(rect, cornerRadius: 999)
        let capsule = Path.roundedRect(rect, cornerRadius: 5)
        #expect(clamped == capsule)
    }
}

@Suite("DrawCommand")
struct DrawCommandTests {

    private let red = Paint.solid(Color(red: 1, green: 0, blue: 0, alpha: 1))

    @Test("A fill is bounded by its path")
    func fillBounds() {
        let command = DrawCommand.fill(Path.rect(SceneRect(x: 5, y: 5, width: 10, height: 10)), red)
        #expect(command.bounds == SceneRect(x: 5, y: 5, width: 10, height: 10))
    }

    @Test("A stroke is bounded by its path grown by half the line width")
    func strokeBounds() {
        let stroke = Stroke(paint: red, width: 4)
        let command = DrawCommand.stroke(
            Path.rect(SceneRect(x: 5, y: 5, width: 10, height: 10)),
            stroke
        )
        #expect(command.bounds == SceneRect(x: 3, y: 3, width: 14, height: 14))
    }

    @Test("Text is bounded by its measured extent")
    func textBounds() {
        let run = TextRun(
            text: "Hi",
            font: FontSpec(family: "Inter", size: 16, weight: .regular),
            baselineOrigin: ScenePoint(x: 10, y: 40),
            paint: red,
            metrics: TextMetrics(width: 20, ascent: 12, descent: 4)
        )
        #expect(DrawCommand.text(run).bounds == SceneRect(x: 10, y: 28, width: 20, height: 16))
    }

    @Test("An image is bounded by its destination rectangle")
    func imageBounds() {
        let command = DrawCommand.image(
            ImageRef(contentHash: "abc", pixelWidth: 10, pixelHeight: 10),
            SceneRect(x: 1, y: 2, width: 3, height: 4),
            opacity: 1,
            cornerRadius: 0
        )
        #expect(command.bounds == SceneRect(x: 1, y: 2, width: 3, height: 4))
    }
}

@Suite("DrawList")
struct DrawListTests {

    private let black = Paint.solid(Color(red: 0, green: 0, blue: 0, alpha: 1))

    private func sample() -> DrawList {
        DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 100),
            colorSpace: .displayP3,
            commands: [
                .fill(Path.rect(SceneRect(x: 0, y: 0, width: 200, height: 100)), black),
                .stroke(
                    Path.polyline(Polyline(points: [P2(x: 10, y: 10), P2(x: 50, y: 60)])),
                    Stroke(paint: black, width: 2)
                ),
                .text(
                    TextRun(
                        text: "Step 1",
                        font: FontSpec(family: "Inter", size: 14, weight: .semibold),
                        baselineOrigin: ScenePoint(x: 60, y: 70),
                        paint: black,
                        metrics: TextMetrics(width: 42.5, ascent: 11, descent: 3)
                    )
                ),
            ]
        )
    }

    @Test("Bounds are the union of every command")
    func bounds() {
        #expect(sample().bounds == SceneRect(x: 0, y: 0, width: 200, height: 100))
    }

    @Test("An empty list has no bounds")
    func emptyBounds() {
        let empty = DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10), colorSpace: .sRGB, commands: [])
        #expect(empty.bounds == nil)
    }

    @Test("The canonical rendering is stable and line oriented")
    func canonicalRendering() throws {
        let goldens = GoldenStore.forRepository(subdirectory: "render")
        let result = try goldens.compare(sample().canonicalText, named: "sample.drawlist.txt")
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("The same list always renders to the same text")
    func renderingIsReproducible() {
        #expect(isReproducible { sample().canonicalText })
    }

    @Test("Differences below the rendering precision do not change the text")
    func precisionIsQuantised() {
        func listOffset(by delta: Double) -> DrawList {
            DrawList(
                canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
                colorSpace: .sRGB,
                commands: [.fill(Path.rect(SceneRect(x: delta, y: 0, width: 1, height: 1)), black)]
            )
        }
        #expect(listOffset(by: 0).canonicalText == listOffset(by: 1e-9).canonicalText)
        #expect(listOffset(by: 0).canonicalText != listOffset(by: 0.5).canonicalText)
    }

    @Test("A dash pattern is part of the stroke's rendering")
    func dashRendering() {
        let list = DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 10, height: 10),
            colorSpace: .sRGB,
            commands: [
                .stroke(
                    Path.polyline(Polyline(points: [P2(x: 0, y: 0), P2(x: 10, y: 0)])),
                    Stroke(paint: black, width: 1, cap: .round, join: .round, dash: [4, 2])
                )
            ]
        )
        #expect(list.canonicalText.contains("dash=[4.000 2.000]"))
        #expect(list.canonicalText.contains("cap=round join=round"))
    }
}
