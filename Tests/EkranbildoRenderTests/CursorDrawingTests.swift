import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("Cursor drawing")
struct CursorDrawingTests {
    private let measurer = TabulatedTextMeasurer.uniform()
    private let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)
    private let image = ImageRef(contentHash: "screenshot", pixelWidth: 800, pixelHeight: 600)

    private func scene(
        cursor: Cursor?,
        background: ImageRef? = nil,
        annotations: [Annotation] = []
    ) -> Scene {
        Scene(
            canvas: canvas,
            background: background,
            annotations: annotations,
            style: .standard,
            cursor: cursor
        )
    }

    private func annotation() -> Annotation {
        Annotation(
            id: AnnotationID(1),
            target: SceneRect(x: 100, y: 140, width: 60, height: 24),
            label: "Save",
            placement: Placement(direction: .e, leaderLength: 70)
        )
    }

    private func build(_ scene: Scene) -> DrawList {
        DrawListBuilder(measurer: measurer).build(scene)
    }

    private func cursor(at x: Double = 200, _ y: Double = 150, opacity: Double = 1, ripple: Double? = nil)
        -> Cursor
    {
        Cursor(position: ScenePoint(x: x, y: y), opacity: opacity, ripple: ripple)
    }

    @Test("A scene with no pointer draws nothing extra")
    func noCursor() {
        #expect(build(scene(cursor: nil)).commands.isEmpty)
    }

    @Test("A scene with a pointer draws it")
    func drawsIt() {
        #expect(!build(scene(cursor: cursor())).commands.isEmpty)
    }

    @Test("A pointer faded away is not drawn")
    func fullyFaded() {
        #expect(build(scene(cursor: cursor(opacity: 0))).commands.isEmpty)
    }

    @Test("The pointer is drawn over the picture and under the annotations")
    func paintingOrder() throws {
        let list = build(
            scene(cursor: cursor(), background: image, annotations: [annotation()]))

        guard case .image = list.commands.first else {
            Issue.record("expected the picture first")
            return
        }
        let cursorAt = try #require(
            list.commands.firstIndex { command in
                if case .fill(let path, _) = command { return path.elements.count > 4 }
                return false
            })
        let annotationAt = try #require(
            list.commands.firstIndex { command in
                if case .stroke(_, let stroke) = command {
                    return stroke.paint == .solid(StyleTokens.standard.leaderColor)
                }
                return false
            })
        #expect(cursorAt < annotationAt)
    }

    @Test("The pointer's tip is exactly where the cursor was")
    func tipIsOnThePosition() throws {
        let at = ScenePoint(x: 213, y: 97)
        let list = build(scene(cursor: Cursor(position: at, opacity: 1, ripple: nil)))

        guard case .stroke(let path, _) = try #require(list.commands.first),
            case .move(let tip) = try #require(path.elements.first)
        else {
            Issue.record("expected the pointer's halo first")
            return
        }
        #expect(approximatelyEqual(tip.x, at.x, tolerance: 1e-9))
        #expect(approximatelyEqual(tip.y, at.y, tolerance: 1e-9))
    }

    @Test("The pointer is outlined so it stays visible over anything")
    func isOutlined() {
        let list = build(scene(cursor: cursor()))
        #expect(
            list.commands.contains { command in
                if case .stroke(_, let stroke) = command {
                    return stroke.paint == .solid(StyleTokens.standard.cursorOutlineColor)
                }
                return false
            })
    }

    @Test("A faded pointer is drawn faintly rather than fully")
    func fades() throws {
        let faint = build(scene(cursor: cursor(opacity: 0.25)))
        guard case .fill(_, .solid(let color)) = try #require(faint.commands.last) else {
            Issue.record("expected the pointer's body last")
            return
        }
        #expect(approximatelyEqual(color.alpha, 0.25, tolerance: 1e-9))
    }

    private func ring(in list: DrawList) -> (path: Path, alpha: Double)? {
        for command in list.commands {
            guard case .stroke(let path, let stroke) = command,
                case .solid(let color) = stroke.paint,
                color.red == StyleTokens.standard.rippleColor.red,
                color.green == StyleTokens.standard.rippleColor.green,
                color.blue == StyleTokens.standard.rippleColor.blue
            else { continue }
            return (path, color.alpha)
        }
        return nil
    }

    @Test("A click draws a ring where it happened")
    func ripple() {
        #expect(ring(in: build(scene(cursor: cursor(ripple: 0.5)))) != nil)
    }

    @Test("With no click there is no ring")
    func noRipple() {
        #expect(ring(in: build(scene(cursor: cursor()))) == nil)
    }

    @Test("A ring grows and fades as the click gets older")
    func rippleGrows() throws {
        func measured(at progress: Double) throws -> (radius: Double, alpha: Double) {
            let drawn = try #require(ring(in: build(scene(cursor: cursor(ripple: progress)))))
            let bounds = try #require(drawn.path.bounds)
            return (bounds.raw.width / 2, drawn.alpha)
        }

        let young = try measured(at: 0.1)
        let old = try measured(at: 0.9)
        #expect(old.radius > young.radius)
        #expect(old.alpha < young.alpha)
    }

    @Test("Drawing the pointer is reproducible")
    func reproducible() {
        let drawn = scene(cursor: cursor(ripple: 0.3), background: image)
        #expect(isReproducible { build(drawn) })
    }
}
