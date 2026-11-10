import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoOverlay
import EkranbildoTestKit
import Testing

@Suite("Capture overlay")
struct OverlayTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 800, height: 600),
        backingScale: 2
    )

    private func window(_ id: UInt32, _ rect: Rect, title: String) -> WindowDescriptor {
        WindowDescriptor(
            id: WindowID(id),
            title: title,
            applicationName: "Test",
            bundleIdentifier: "test",
            frame: ScreenRect(rect),
            isOnScreen: true,
            layer: 0
        )
    }

    private func overlay() -> Overlay {
        Overlay(
            frozen: FrozenScreen(
                display: Self.display,
                image: SceneLibrary.applicationWindow.image,
                windows: WindowStack(windows: [
                    window(1, Rect(x: 100, y: 100, width: 300, height: 200), title: "Front"),
                    window(2, Rect(x: 0, y: 0, width: 800, height: 600), title: "Behind"),
                ])
            )
        )
    }

    private func after(_ events: [InputEvent], from start: Overlay) -> Overlay {
        var state = start
        for event in events {
            state = state.handle(event)
        }
        return state
    }

    @Test("Nothing is chosen to begin with")
    func startsEmpty() {
        let overlay = overlay()
        #expect(overlay.selection == nil)
        #expect(overlay.outcome == nil)
    }

    @Test("The window under the pointer is offered")
    func highlightsWindow() {
        let moved = after([.pointerMoved(ScenePoint(x: 200, y: 150), .plain)], from: overlay())
        #expect(moved.highlighted?.title == "Front")
    }

    @Test("Nothing is offered where no window is")
    func noWindowThere() {
        let moved = after([.pointerMoved(ScenePoint(x: 790, y: 590), .plain)], from: overlay())
        #expect(moved.highlighted?.title == "Behind")
    }

    @Test("Dragging sweeps out a region")
    func sweepsRegion() throws {
        let dragged = after(
            [
                .pointerDown(ScenePoint(x: 50, y: 40), .plain),
                .pointerMoved(ScenePoint(x: 250, y: 190), .plain),
            ],
            from: overlay()
        )
        let selection = try #require(dragged.selection)
        #expect(selection.raw == Rect(x: 50, y: 40, width: 200, height: 150))
    }

    @Test("Sweeping backwards gives the same region")
    func sweepsBackwards() throws {
        let dragged = after(
            [
                .pointerDown(ScenePoint(x: 250, y: 190), .plain),
                .pointerMoved(ScenePoint(x: 50, y: 40), .plain),
            ],
            from: overlay()
        )
        #expect(try #require(dragged.selection).raw == Rect(x: 50, y: 40, width: 200, height: 150))
    }

    @Test("A region near a window's edges takes them")
    func snapsToWindow() throws {
        let dragged = after(
            [
                .pointerDown(ScenePoint(x: 103, y: 98), .plain),
                .pointerMoved(ScenePoint(x: 397, y: 303), .plain),
            ],
            from: overlay()
        )
        let selection = try #require(dragged.selection)
        #expect(selection.minX == 100)
        #expect(selection.minY == 100)
        #expect(selection.maxX == 400)
        #expect(selection.maxY == 300)
    }

    @Test("Holding option turns snapping off")
    func optionDisablesSnapping() throws {
        let dragged = after(
            [
                .pointerDown(ScenePoint(x: 103, y: 98), .option),
                .pointerMoved(ScenePoint(x: 397, y: 303), .option),
            ],
            from: overlay()
        )
        #expect(try #require(dragged.selection).minX == 103)
    }

    @Test("Letting go after a drag chooses that region")
    func choosesRegion() throws {
        let done = after(
            [
                .pointerDown(ScenePoint(x: 50, y: 40), .plain),
                .pointerMoved(ScenePoint(x: 250, y: 190), .plain),
                .pointerUp(ScenePoint(x: 250, y: 190), .plain),
            ],
            from: overlay()
        )
        guard case .region(let rect) = done.outcome else {
            Issue.record("expected a region: \(String(describing: done.outcome))")
            return
        }
        #expect(rect.raw == Rect(x: 50, y: 40, width: 200, height: 150))
    }

    @Test("Clicking without dragging chooses the window under the pointer")
    func choosesWindow() {
        let done = after(
            [
                .pointerMoved(ScenePoint(x: 200, y: 150), .plain),
                .pointerDown(ScenePoint(x: 200, y: 150), .plain),
                .pointerUp(ScenePoint(x: 200, y: 150), .plain),
            ],
            from: overlay()
        )
        guard case .window(let id) = done.outcome else {
            Issue.record("expected a window: \(String(describing: done.outcome))")
            return
        }
        #expect(id == WindowID(1))
    }

    @Test("A sweep too small to be a region is not one")
    func tinySweepIsNotARegion() {
        let done = after(
            [
                .pointerMoved(ScenePoint(x: 200, y: 150), .plain),
                .pointerDown(ScenePoint(x: 200, y: 150), .plain),
                .pointerMoved(ScenePoint(x: 201, y: 151), .plain),
                .pointerUp(ScenePoint(x: 201, y: 151), .plain),
            ],
            from: overlay()
        )
        guard case .window = done.outcome else {
            Issue.record("a tiny sweep should still choose the window")
            return
        }
    }

    @Test("Escape cancels")
    func escapeCancels() {
        let done = after([.key(.escape, .plain)], from: overlay())
        #expect(done.outcome == .cancelled)
    }

    @Test("Escape during a drag cancels rather than choosing")
    func escapeDuringDrag() {
        let done = after(
            [
                .pointerDown(ScenePoint(x: 50, y: 40), .plain),
                .pointerMoved(ScenePoint(x: 250, y: 190), .plain),
                .key(.escape, .plain),
            ],
            from: overlay()
        )
        #expect(done.outcome == .cancelled)
        #expect(done.selection == nil)
    }

    @Test("Enter chooses the whole display")
    func enterChoosesDisplay() {
        let done = after([.key(.enter, .plain)], from: overlay())
        #expect(done.outcome == .display(Self.display.displayID))
    }

    @Test("Nothing changes after a choice has been made")
    func settled() {
        let chosen = after(
            [
                .pointerDown(ScenePoint(x: 50, y: 40), .plain),
                .pointerMoved(ScenePoint(x: 250, y: 190), .plain),
                .pointerUp(ScenePoint(x: 250, y: 190), .plain),
            ],
            from: overlay()
        )
        guard case .region(let chosenRect) = chosen.outcome else {
            Issue.record("expected a region")
            return
        }

        let after = after(
            [
                .pointerMoved(ScenePoint(x: 200, y: 150), .plain),
                .pointerDown(ScenePoint(x: 10, y: 10), .plain),
                .pointerMoved(ScenePoint(x: 300, y: 250), .plain),
                .pointerUp(ScenePoint(x: 300, y: 250), .plain),
                .key(.escape, .plain),
            ],
            from: chosen
        )
        #expect(after.outcome == .region(chosenRect))
        #expect(after.selection == chosen.selection)
        #expect(after.highlighted == chosen.highlighted)
    }

    @Test("The same events give the same result")
    func reproducible() {
        let events: [InputEvent] = [
            .pointerMoved(ScenePoint(x: 120, y: 120), .plain),
            .pointerDown(ScenePoint(x: 103, y: 98), .plain),
            .pointerMoved(ScenePoint(x: 397, y: 303), .plain),
            .pointerUp(ScenePoint(x: 397, y: 303), .plain),
        ]
        let start = overlay()
        #expect(isReproducible { after(events, from: start).outcome })
    }
}
