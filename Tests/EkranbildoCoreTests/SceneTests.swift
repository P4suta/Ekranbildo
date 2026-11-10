import EkranbildoContracts
@testable import EkranbildoCore
import EkranbildoGeometry
import Foundation
import Testing

@Suite("Placement geometry")
struct PlacementGeometryTests {
    private let target = SceneRect(x: 100, y: 100, width: 40, height: 20)
    private let style = StyleTokens.standard

    @Test("The tip sits outside the target by the configured gap")
    func tipClearsTheTarget() {
        let resolved = ResolvedPlacement(
            target: target,
            placement: Placement(direction: .e, leaderLength: 60),
            style: style
        )
        #expect(resolved.tip.x > target.maxX)
        #expect(approximatelyEqual(resolved.tip.x - target.maxX, style.tipGap))
    }

    @Test("The tip leaves the target along the placement direction")
    func tipFollowsDirection() {
        for direction in [Direction16.e, .w, .n, .s] {
            let resolved = ResolvedPlacement(
                target: target,
                placement: Placement(direction: direction, leaderLength: 50),
                style: style
            )
            let outward = resolved.tip.raw - target.raw.center
            #expect(outward.dot(direction.unit) > 0)
        }
    }

    @Test("The tail is the leader's length away from the tip")
    func tailDistance() {
        let resolved = ResolvedPlacement(
            target: target,
            placement: Placement(direction: .ne, leaderLength: 80),
            style: style
        )
        let distance = Geo.distanceSquared(resolved.tail.raw, resolved.tip.raw)
        #expect(approximatelyEqual(distance, 80 * 80, tolerance: 1e-6))
    }

    @Test("The leader points back at the target from the tail")
    func leaderDirection() {
        let resolved = ResolvedPlacement(
            target: target,
            placement: Placement(direction: .e, leaderLength: 60),
            style: style
        )
        #expect(resolved.tail.x > resolved.tip.x)
        #expect(approximatelyEqual(resolved.tail.y, resolved.tip.y))
    }

    @Test("Mirroring the target and direction mirrors the placement")
    func mirroringIsConsistent() {
        let axis = 500.0
        func mirrored(_ rect: SceneRect) -> SceneRect {
            SceneRect(x: 2 * axis - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
        }

        let original = ResolvedPlacement(
            target: target,
            placement: Placement(direction: .ene, leaderLength: 70),
            style: style
        )
        let flipped = ResolvedPlacement(
            target: mirrored(target),
            placement: Placement(direction: Direction16.ene.mirroredHorizontally, leaderLength: 70),
            style: style
        )

        #expect(approximatelyEqual(flipped.tip.x, 2 * axis - original.tip.x, tolerance: 1e-9))
        #expect(approximatelyEqual(flipped.tip.y, original.tip.y, tolerance: 1e-9))
        #expect(approximatelyEqual(flipped.tail.x, 2 * axis - original.tail.x, tolerance: 1e-9))
    }

    @Test("A zero-length leader still produces a tip clear of the target")
    func degenerateLength() {
        let resolved = ResolvedPlacement(
            target: target,
            placement: Placement(direction: .s, leaderLength: 0),
            style: style
        )
        #expect(resolved.tip == resolved.tail)
        #expect(resolved.tip.y > target.maxY)
    }
}

@Suite("Label box")
struct LabelBoxTests {
    private let target = SceneRect(x: 100, y: 100, width: 40, height: 20)
    private let style = StyleTokens.standard
    private let textSize = Size(width: 60, height: 16)

    private func resolved(_ direction: Direction16, length: Double = 50) -> ResolvedPlacement {
        ResolvedPlacement(
            target: target,
            placement: Placement(direction: direction, leaderLength: length),
            style: style
        )
    }

    @Test("The box is the text plus padding on every side")
    func boxSize() {
        let box = resolved(.e).labelBox(textSize: textSize, style: style)
        #expect(approximatelyEqual(box.width, 60 + 2 * style.labelPaddingHorizontal))
        #expect(approximatelyEqual(box.height, 16 + 2 * style.labelPaddingVertical))
    }

    @Test("The tail lands on the box border", arguments: Direction16.allCases)
    func tailTouchesTheBox(_ direction: Direction16) {
        let placement = resolved(direction)
        let box = placement.labelBox(textSize: textSize, style: style)
        #expect(Geo.distanceSquared(from: placement.tail.raw, to: box.raw) < 1e-9)
    }

    @Test("The leader never passes through the box", arguments: Direction16.allCases)
    func leaderClearsTheBox(_ direction: Direction16) {
        let placement = resolved(direction)
        let box = placement.labelBox(textSize: textSize, style: style)
        #expect(
            !Geo.segmentIntersectsInterior(
                Segment(a: placement.tail.raw, b: placement.tip.raw),
                of: box.raw
            )
        )
    }

    @Test("A longer leader pushes the box further out", arguments: Direction16.allCases)
    func longerLeaderMovesTheBox(_ direction: Direction16) {
        let near = resolved(direction, length: 20).labelBox(textSize: textSize, style: style)
        let far = resolved(direction, length: 120).labelBox(textSize: textSize, style: style)
        let outward = direction.unit
        #expect((far.raw.center - near.raw.center).dot(outward) > 0)
    }

    @Test("The baseline sits inside the box below its top padding")
    func baselinePosition() {
        let metrics = TextMetrics(width: 60, ascent: 12, descent: 4)
        let placement = resolved(.s)
        let box = placement.labelBox(textSize: Size(width: 60, height: 16), style: style)
        let baseline = placement.labelBaseline(metrics: metrics, style: style)
        #expect(approximatelyEqual(baseline.x, box.minX + style.labelPaddingHorizontal))
        #expect(approximatelyEqual(baseline.y, box.minY + style.labelPaddingVertical + 12))
    }
}

@Suite("Scene")
struct SceneTests {

    @Test("An empty scene has a canvas and no annotations")
    func emptyScene() {
        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 50),
            background: nil,
            annotations: [],
            style: .standard
        )
        #expect(scene.annotations.isEmpty)
        #expect(scene.canvas.width == 100)
    }

    @Test("Annotations keep the order they were given")
    func annotationOrder() {
        let scene = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 50),
            background: nil,
            annotations: [
                Annotation(
                    id: AnnotationID(1),
                    target: SceneRect(x: 0, y: 0, width: 10, height: 10),
                    label: "first",
                    placement: Placement(direction: .e, leaderLength: 10)
                ),
                Annotation(
                    id: AnnotationID(2),
                    target: SceneRect(x: 20, y: 0, width: 10, height: 10),
                    label: "second",
                    placement: Placement(direction: .w, leaderLength: 10)
                ),
            ],
            style: .standard
        )
        #expect(scene.annotations.map(\.label) == ["first", "second"])
        #expect(scene.annotations.map(\.id.raw) == [1, 2])
    }
}

@Suite("Scene decoding")
struct SceneDecodingTests {

    @Test("A missing style decodes as the standard style")
    func missingStyleDefaults() throws {
        let json = """
            {
              "canvas": { "raw": { "origin": { "x": 0, "y": 0 },
                                   "size": { "width": 10, "height": 10 } } },
              "background": null,
              "annotations": []
            }
            """
        let scene = try JSONDecoder().decode(Scene.self, from: Data(json.utf8))
        #expect(scene.style == StyleTokens.standard)
    }

    @Test("An explicit null style also decodes as the standard style")
    func nullStyleDefaults() throws {
        let json = """
            {
              "canvas": { "raw": { "origin": { "x": 0, "y": 0 },
                                   "size": { "width": 10, "height": 10 } } },
              "background": null,
              "annotations": [],
              "style": null
            }
            """
        let scene = try JSONDecoder().decode(Scene.self, from: Data(json.utf8))
        #expect(scene.style == StyleTokens.standard)
    }

    @Test("A scene survives a round trip through JSON")
    func roundTrip() throws {
        var custom = StyleTokens.standard
        custom.tipGap = 11
        custom.labelPlateCornerRadius = 3
        custom.labelFont = FontSpec(family: "Some Other Face", size: 19, weight: .bold, italic: true)

        let original = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 100),
            background: ImageRef(contentHash: "abc", pixelWidth: 4, pixelHeight: 4),
            annotations: [
                Annotation(
                    id: AnnotationID(7),
                    target: SceneRect(x: 1, y: 2, width: 3, height: 4),
                    label: "Label",
                    placement: Placement(direction: .nw, leaderLength: 12)
                )
            ],
            style: custom
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)
        #expect(decoded == original)
        #expect(decoded.style.tipGap == 11)
    }
}
