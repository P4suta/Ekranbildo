import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("DrawListBuilder")
struct DrawListBuilderTests {
    private let measurer = TabulatedTextMeasurer.uniform()
    private let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene(
        background: ImageRef? = nil,
        annotations: [Annotation] = []
    ) -> Scene {
        Scene(canvas: canvas, background: background, annotations: annotations, style: .standard)
    }

    private func singleAnnotation(direction: Direction16 = .e, label: String = "Save") -> Annotation {
        Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 100, y: 140, width: 60, height: 24),
            label: label,
            placement: Placement(direction: direction, leaderLength: 70)
        )
    }

    private func build(_ scene: Scene) -> DrawList {
        DrawListBuilder(measurer: measurer).build(scene)
    }

    @Test("An empty scene draws nothing but keeps the canvas")
    func emptyScene() {
        let list = build(scene())
        #expect(list.commands.isEmpty)
        #expect(list.canvas == canvas)
    }

    @Test("The background is drawn first and fills the canvas")
    func backgroundIsFirst() {
        let image = ImageRef(contentHash: "screenshot", pixelWidth: 800, pixelHeight: 600)
        let list = build(scene(background: image, annotations: [singleAnnotation()]))
        guard case .image(let ref, let rect, _, _) = list.commands.first else {
            Issue.record("expected an image command first, got \(String(describing: list.commands.first))")
            return
        }
        #expect(ref == image)
        #expect(rect == canvas)
    }

    @Test("One annotation draws leader, arrowhead, plate and text in that order")
    func paintingOrder() {
        let list = build(scene(annotations: [singleAnnotation()]))
        #expect(list.commands.count == 4)

        guard case .stroke = list.commands[0] else {
            Issue.record("expected the leader stroke first")
            return
        }
        guard case .fill = list.commands[1] else {
            Issue.record("expected the arrowhead second")
            return
        }
        guard case .fill = list.commands[2] else {
            Issue.record("expected the label plate third")
            return
        }
        guard case .text = list.commands[3] else {
            Issue.record("expected the label text last")
            return
        }
    }

    @Test("The label plate is large enough for the text plus padding")
    func plateFitsTheText() {
        let style = StyleTokens.standard
        let annotation = singleAnnotation(label: "Save")
        let list = build(scene(annotations: [annotation]))
        guard case .fill(let path, _) = list.commands[2], let plate = path.bounds else {
            Issue.record("expected a label plate")
            return
        }
        let metrics = measurer.measure("Save", font: style.labelFont)
        #expect(approximatelyEqual(plate.width, metrics.width + 2 * style.labelPaddingHorizontal))
        #expect(approximatelyEqual(plate.height, metrics.height + 2 * style.labelPaddingVertical))
    }

    @Test("The label text sits inside its plate")
    func textIsInsideThePlate() {
        let list = build(scene(annotations: [singleAnnotation()]))
        guard case .fill(let path, _) = list.commands[2], let plate = path.bounds,
            case .text(let run) = list.commands[3]
        else {
            Issue.record("expected a plate and a text run")
            return
        }
        let text = run.bounds
        #expect(text.minX >= plate.minX - 1e-9)
        #expect(text.maxX <= plate.maxX + 1e-9)
        #expect(text.minY >= plate.minY - 1e-9)
        #expect(text.maxY <= plate.maxY + 1e-9)
    }

    @Test("The label begins where the leader ends", arguments: [Direction16.e, .w, .n, .s, .ne, .sw])
    func labelBeginsWhereTheLeaderEnds(_ direction: Direction16) {
        let annotation = singleAnnotation(direction: direction)
        let list = build(scene(annotations: [annotation]))
        guard case .fill(let path, _) = list.commands[2], let plate = path.bounds else {
            Issue.record("expected a label plate")
            return
        }
        let resolved = ResolvedPlacement(
            target: annotation.target,
            placement: annotation.placement!,
            style: .standard
        )
        let tail = resolved.tail.raw

        #expect(Geo.distanceSquared(from: tail, to: plate.raw) < 1e-9)

        #expect(!Geo.segmentIntersectsInterior(Segment(a: tail, b: resolved.tip.raw), of: plate.raw))
        #expect(!plate.raw.contains(resolved.tip.raw))
        #expect(!Geo.overlaps(plate.raw, annotation.target.raw))
    }

    @Test("The arrowhead is a triangle pointing at the tip")
    func arrowheadShape() {
        let annotation = singleAnnotation(direction: .e)
        let list = build(scene(annotations: [annotation]))
        guard case .fill(let path, _) = list.commands[1] else {
            Issue.record("expected an arrowhead")
            return
        }
        #expect(path.elements.count == 4)

        let resolved = ResolvedPlacement(
            target: annotation.target,
            placement: annotation.placement!,
            style: .standard
        )
        guard case .move(let apex) = path.elements[0] else {
            Issue.record("expected the apex first")
            return
        }
        #expect(approximatelyEqual(apex.x, resolved.tip.x))
        #expect(approximatelyEqual(apex.y, resolved.tip.y))

        let outward = resolved.direction.unit
        for element in path.elements.dropFirst() {
            for point in element.referencedPoints {
                #expect((point.raw - apex.raw).dot(outward) > 0)
            }
        }
    }

    @Test("The leader runs from the label end to the tip")
    func leaderSpan() {
        let annotation = singleAnnotation(direction: .e)
        let list = build(scene(annotations: [annotation]))
        guard case .stroke(let path, let stroke) = list.commands[0] else {
            Issue.record("expected a leader stroke")
            return
        }
        #expect(stroke.width == StyleTokens.standard.leaderWidth)
        #expect(path.elements.count == 2)
    }

    @Test("Several annotations are drawn in order, four commands each")
    func multipleAnnotations() {
        let annotations = (1...3).map { index in
            Annotation(
                id: AnnotationID(UInt32(index)),
                target: SceneRect(x: Double(index) * 50, y: 100, width: 30, height: 20),
                label: "Step \(index)",
                placement: Placement(direction: .n, leaderLength: 40)
            )
        }
        let list = build(scene(annotations: annotations))
        #expect(list.commands.count == 12)
    }

    @Test("An annotation without a placement is skipped rather than guessed at")
    func unplacedAnnotationIsSkipped() {
        let annotation = Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 0, y: 0, width: 10, height: 10),
            label: "unsolved",
            placement: nil
        )
        #expect(build(scene(annotations: [annotation])).commands.isEmpty)
    }

    @Test("Building the same scene twice produces identical output")
    func buildingIsReproducible() {
        let subject = scene(annotations: [singleAnnotation()])
        #expect(isReproducible { build(subject).canonicalText })
    }

    @Test("A CJK label produces a wider plate than a Latin one of the same length")
    func wideLabels() {
        func plateWidth(for label: String) -> Double {
            let list = build(scene(annotations: [singleAnnotation(label: label)]))
            guard case .fill(let path, _) = list.commands[2], let plate = path.bounds else { return 0 }
            return plate.width
        }
        #expect(plateWidth(for: "保存") > plateWidth(for: "ab"))
    }
}
