import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoOverlay
import Testing

@Suite("Snapping to what is on the screen")
struct SnappingToThingsTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 800, height: 600),
        backingScale: 1
    )

    private static let button = SceneRect(x: 200, y: 150, width: 80, height: 30)
    private static let toolbar = SceneRect(x: 150, y: 140, width: 400, height: 50)
    private static let window = SceneRect(x: 100, y: 100, width: 600, height: 400)

    private static func overlay(knowing elements: [SceneRect] = []) -> Overlay {
        var overlay = Overlay(
            frozen: FrozenScreen(
                display: display,
                image: ImageBuffer(
                    width: 800,
                    height: 600,
                    colorSpace: .displayP3,
                    pixels: [UInt8](repeating: 128, count: 800 * 600 * 4)
                ),
                windows: WindowStack(windows: [])
            )
        )
        overlay.learned(
            elements.map { ScreenElement(rect: $0, kind: .surface, confidence: 1, provenance: .given) })
        return overlay
    }

    private func clicking(_ point: ScenePoint, in overlay: Overlay) -> Overlay {
        overlay
            .handle(.pointerDown(point, []))
            .handle(.pointerUp(point, []))
    }

    private static let inTheButton = ScenePoint(x: 230, y: 165)

    @Test("Clicking something takes that thing")
    func clickingTakesTheThing() {
        let after = clicking(
            Self.inTheButton, in: Self.overlay(knowing: [Self.button, Self.toolbar, Self.window]))
        #expect(after.outcome == .region(ScreenRect(Self.button.raw)))
    }

    @Test("Clicking again widens to what holds it")
    func clickingAgainWidens() {
        var overlay = Self.overlay(knowing: [Self.button, Self.toolbar, Self.window])
        overlay = overlay.handle(.pointerMoved(Self.inTheButton, []))
        #expect(overlay.snapped == Self.button)

        overlay = overlay.handle(.widen)
        #expect(overlay.snapped == Self.toolbar)

        overlay = overlay.handle(.widen)
        #expect(overlay.snapped == Self.window)
    }

    @Test("Widening past the biggest stays at the biggest")
    func widestIsTheLimit() {
        var overlay = Self.overlay(knowing: [Self.button, Self.window])
        overlay = overlay.handle(.pointerMoved(Self.inTheButton, []))
        for _ in 0..<5 { overlay = overlay.handle(.widen) }
        #expect(overlay.snapped == Self.window)
    }

    @Test("Pointing somewhere else starts again at the smallest")
    func movingResets() {
        var overlay = Self.overlay(knowing: [Self.button, Self.toolbar, Self.window])
        overlay = overlay.handle(.pointerMoved(Self.inTheButton, []))
        overlay = overlay.handle(.widen)
        #expect(overlay.snapped == Self.toolbar)

        overlay = overlay.handle(.pointerMoved(ScenePoint(x: 600, y: 450), []))
        #expect(overlay.snapped == Self.window)
    }

    @Test("With nothing detected there is nothing to snap to")
    func nothingDetected() {
        var overlay = Self.overlay()
        overlay = overlay.handle(.pointerMoved(Self.inTheButton, []))
        #expect(overlay.snapped == nil)
    }

    @Test("A drag is still the region that was dragged")
    func draggingIsUnchanged() {
        var overlay = Self.overlay(knowing: [Self.button, Self.window])
        overlay = overlay.handle(.pointerDown(ScenePoint(x: 300, y: 300), [.option]))
        overlay = overlay.handle(.pointerMoved(ScenePoint(x: 500, y: 420), [.option]))
        overlay = overlay.handle(.pointerUp(ScenePoint(x: 500, y: 420), [.option]))
        #expect(
            overlay.outcome
                == .region(ScreenRect(Rect(x: 300, y: 300, width: 200, height: 120))))
    }

    @Test("What is snapped to is in the screen's own coordinates")
    func onASecondDisplay() {
        let elsewhere = DisplayGeometry(
            displayID: 5,
            bounds: Rect(x: -1920, y: -600, width: 800, height: 600),
            backingScale: 1
        )
        var overlay = Overlay(
            frozen: FrozenScreen(
                display: elsewhere,
                image: ImageBuffer(
                    width: 800,
                    height: 600,
                    colorSpace: .displayP3,
                    pixels: [UInt8](repeating: 128, count: 800 * 600 * 4)
                ),
                windows: WindowStack(windows: [])
            )
        )
        overlay.learned([ScreenElement(rect: Self.button, kind: .surface, confidence: 1, provenance: .given)])
        let after = clicking(Self.inTheButton, in: overlay)
        #expect(
            after.outcome
                == .region(ScreenRect(Rect(x: -1720, y: -450, width: 80, height: 30))))
    }
}

@Suite("Showing what a click would take")
struct ShowingTheSnapTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 800, height: 600),
        backingScale: 1
    )
    private static let button = SceneRect(x: 200, y: 150, width: 80, height: 30)

    private static func overlay(knowing elements: [SceneRect]) -> Overlay {
        var overlay = Overlay(
            frozen: FrozenScreen(
                display: display,
                image: ImageBuffer(
                    width: 800,
                    height: 600,
                    colorSpace: .displayP3,
                    pixels: [UInt8](repeating: 128, count: 800 * 600 * 4)
                ),
                windows: WindowStack(windows: [])
            )
        )
        overlay.learned(
            elements.map {
                ScreenElement(rect: $0, kind: .surface, confidence: 1, provenance: .given)
            })
        return overlay
    }

    private func outlines(_ overlay: Overlay) -> [SceneRect] {
        overlay.drawList.commands.compactMap { command -> SceneRect? in
            guard case .stroke(let path, _) = command else { return nil }
            return path.bounds
        }
    }

    @Test("What would be taken is outlined")
    func outlined() {
        let overlay = Self.overlay(knowing: [Self.button])
            .handle(.pointerMoved(ScenePoint(x: 230, y: 165), []))
        #expect(outlines(overlay) == [Self.button])
    }

    @Test("With nothing under the pointer nothing is outlined")
    func nothingUnderIt() {
        let overlay = Self.overlay(knowing: [Self.button])
            .handle(.pointerMoved(ScenePoint(x: 600, y: 500), []))
        #expect(outlines(overlay).isEmpty)
    }

    @Test("While sweeping, only the sweep is outlined")
    func whileSweeping() {
        var overlay = Self.overlay(knowing: [Self.button])
        overlay = overlay.handle(.pointerMoved(ScenePoint(x: 230, y: 165), []))
        overlay = overlay.handle(.pointerDown(ScenePoint(x: 300, y: 300), [.option]))
        overlay = overlay.handle(.pointerMoved(ScenePoint(x: 500, y: 420), [.option]))
        #expect(outlines(overlay) == [SceneRect(x: 300, y: 300, width: 200, height: 120)])
    }
}
