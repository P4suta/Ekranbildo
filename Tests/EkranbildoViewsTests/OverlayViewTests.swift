import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay
@testable import EkranbildoViews
import Testing

@Suite("The overlay view", .serialized)
@MainActor
struct OverlayViewTests {

    private static func display(at origin: P2, scale: Double = 1) -> DisplayGeometry {
        DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: origin.x, y: origin.y, width: 800, height: 600),
            backingScale: scale
        )
    }

    private static func frozen(
        at origin: P2 = P2(x: 0, y: 0),
        scale: Double = 1
    ) -> FrozenScreen {
        let display = display(at: origin, scale: scale)
        return FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: Int(display.bounds.width * scale),
                height: Int(display.bounds.height * scale),
                colorSpace: .displayP3,
                pixels: [UInt8](
                    repeating: Grey.value,
                    count: Int(display.bounds.width * scale)
                        * Int(display.bounds.height * scale) * Grey.channels)
            ),
            windows: WindowStack(windows: [])
        )
    }

    private enum Grey {
        static let value: UInt8 = 128
        static let channels = 4
    }

    private func view(_ frozen: FrozenScreen) -> OverlayView {
        let store = AssetStore()
        store.put(frozen.image, as: Overlay.frozenName(of: frozen))
        let view = OverlayView(overlay: Overlay(frozen: frozen), assets: store)
        view.frame = NSRect(
            x: 0,
            y: 0,
            width: frozen.display.bounds.width,
            height: frozen.display.bounds.height
        )
        return view
    }

    private func event(_ type: NSEvent.EventType, atWindowPoint point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    private func drag(_ view: OverlayView, from: P2, to: P2) throws {
        let height = view.bounds.height
        func flipped(_ point: P2) -> NSPoint {
            NSPoint(x: point.x, y: height - point.y)
        }
        view.mouseDown(with: try event(.leftMouseDown, atWindowPoint: flipped(from)))
        view.mouseDragged(with: try event(.leftMouseDragged, atWindowPoint: flipped(to)))
        view.mouseUp(with: try event(.leftMouseUp, atWindowPoint: flipped(to)))
    }

    private func selecting(_ view: OverlayView) {
        view.send = { [weak view] incoming in
            guard let view else { return }
            view.overlay = view.overlay.handle(incoming)
        }
    }

    @Test("A drag chooses the region it swept out")
    func dragChoosesARegion() throws {
        let view = view(Self.frozen())
        selecting(view)
        try drag(view, from: P2(x: 100, y: 120), to: P2(x: 400, y: 320))

        #expect(
            view.overlay.outcome
                == .region(
                    ScreenRect(
                        Rect(
                            x: 100, y: 120, width: 300, height: 200))))
    }

    @Test("A drag on a display away from the origin chooses a region on that display")
    func dragOnASecondDisplay() throws {
        let view = view(Self.frozen(at: P2(x: -1920, y: -600)))
        selecting(view)
        try drag(view, from: P2(x: 100, y: 120), to: P2(x: 400, y: 320))

        #expect(
            view.overlay.outcome
                == .region(
                    ScreenRect(
                        Rect(
                            x: -1820, y: -480, width: 300, height: 200))))
    }

    @Test("What a click takes is the window under the pointer on that display")
    func hoverOnASecondDisplay() throws {
        let origin = P2(x: -1920, y: -600)
        var frozen = Self.frozen(at: origin)
        frozen = FrozenScreen(
            display: frozen.display,
            image: frozen.image,
            windows: WindowStack(windows: [
                WindowDescriptor(
                    id: WindowID(7),
                    title: "Front",
                    applicationName: "Test",
                    bundleIdentifier: "test",
                    frame: ScreenRect(
                        Rect(x: origin.x + 50, y: origin.y + 50, width: 200, height: 150)),
                    isOnScreen: true,
                    layer: 0
                )
            ])
        )
        let view = view(frozen)
        selecting(view)
        view.mouseMoved(
            with: try event(.mouseMoved, atWindowPoint: NSPoint(x: 100, y: view.bounds.height - 100))
        )

        #expect(view.overlay.highlighted?.id == WindowID(7))
    }
}
