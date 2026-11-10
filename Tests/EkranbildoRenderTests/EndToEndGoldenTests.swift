import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("End-to-end golden")
struct EndToEndGoldenTests {
    private let goldens = GoldenStore.forRepository(subdirectory: "render")

    private func sampleScene() -> Scene {
        Scene(
            canvas: SceneRect(x: 0, y: 0, width: 480, height: 300),
            background: ImageRef(contentHash: "sample-screenshot", pixelWidth: 960, pixelHeight: 600),
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 60, y: 40, width: 120, height: 28),
                    label: "Search field",
                    placement: Placement(direction: .se, leaderLength: 64)
                ),
                Annotation(
                    id: AnnotationID(2),
                    target: SceneRect(x: 330, y: 210, width: 90, height: 32),
                    label: "保存",
                    placement: Placement(direction: .nw, leaderLength: 72)
                ),
                Annotation(
                    id: AnnotationID(3),
                    target: SceneRect(x: 210, y: 140, width: 44, height: 44),
                    label: "Toggle",
                    placement: Placement(direction: .e, leaderLength: 58)
                ),
            ],
            style: .standard
        )
    }

    private func drawList() -> DrawList {
        DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(sampleScene())
    }

    @Test("The draw list for the sample scene is unchanged")
    func drawListGolden() throws {
        let result = try goldens.compare(drawList().canonicalText, named: "sample-scene.drawlist")
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("The SVG for the sample scene is unchanged")
    func svgGolden() throws {
        let renderer = SVGRenderer(imageHref: { "assets/\($0.contentHash).png" })
        let result = try goldens.compare(renderer.render(drawList()), named: "sample-scene.svg")
        #expect(result.isAcceptable, "\(result.message)")
    }

    @Test("Nothing in the sample scene is drawn outside the canvas")
    func everythingIsInsideTheCanvas() {
        let canvas = sampleScene().canvas.raw
        for (index, command) in drawList().commands.enumerated() {
            guard let bounds = command.bounds?.raw else { continue }
            #expect(canvas.contains(bounds), "command \(index) extends outside the canvas: \(bounds)")
        }
    }

    @Test("Mirroring the scene mirrors every drawn point")
    func mirroringIsConsistent() {
        let scene = sampleScene()
        let width = scene.canvas.width

        func mirrored(_ rect: SceneRect) -> SceneRect {
            SceneRect(x: width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
        }

        let flippedScene = Scene(
            canvas: scene.canvas,
            background: scene.background,
            annotations: scene.annotations.map { annotation in
                Annotation(
                    id: annotation.id,
                    target: mirrored(annotation.target),
                    label: annotation.label,
                    placement: annotation.placement.map {
                        Placement(
                            direction: $0.direction.mirroredHorizontally,
                            leaderLength: $0.leaderLength
                        )
                    }
                )
            },
            style: scene.style
        )

        let builder = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
        let original = builder.build(scene)
        let flipped = builder.build(flippedScene)

        #expect(original.commands.count == flipped.commands.count)
        for (lhs, rhs) in zip(original.commands, flipped.commands) {
            guard let lhsBounds = lhs.bounds, let rhsBounds = rhs.bounds else { continue }
            #expect(approximatelyEqual(rhsBounds.minX, width - lhsBounds.maxX, tolerance: 1e-9))
            #expect(approximatelyEqual(rhsBounds.minY, lhsBounds.minY, tolerance: 1e-9))
            #expect(approximatelyEqual(rhsBounds.width, lhsBounds.width, tolerance: 1e-9))
        }
    }
}
