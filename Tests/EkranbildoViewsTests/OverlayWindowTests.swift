import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay
@testable import EkranbildoViews
import Testing

@Suite("The overlay window", .serialized)
@MainActor
struct OverlayWindowTests {

    private static var width: Double { Double(NSScreen.main?.frame.width ?? 0) }
    private static var height: Double { Double(NSScreen.main?.frame.height ?? 0) }

    private static func frozen(at origin: P2 = P2(x: 0, y: 0)) -> FrozenScreen {
        let display = DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: origin.x, y: origin.y, width: width, height: height),
            backingScale: 1
        )
        return FrozenScreen(
            display: display,
            image: ImageBuffer(
                width: Int(width),
                height: Int(height),
                colorSpace: .displayP3,
                pixels: [UInt8](repeating: Grey.value, count: Int(width * height) * Grey.channels)
            ),
            windows: WindowStack(windows: [])
        )
    }

    private enum Grey {
        static let value: UInt8 = 128
        static let channels = 4
    }

    private func window(_ frozen: FrozenScreen) throws -> (OverlayWindow, OverlayView) {
        let store = AssetStore()
        store.put(frozen.image, as: Overlay.frozenName(of: frozen))
        let view = OverlayView(overlay: Overlay(frozen: frozen), assets: store)
        let screen = try #require(NSScreen.main)
        let window = OverlayWindow(view: view, screen: screen)
        view.send = { [weak view] event in
            guard let view else { return }
            view.overlay = view.overlay.handle(event)
        }
        return (window, view)
    }

    private func event(
        _ type: NSEvent.EventType,
        at point: NSPoint,
        in window: NSWindow
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: point,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    @Test("The window will become key")
    func becomesKey() throws {
        let (window, _) = try window(Self.frozen())
        #expect(window.canBecomeKey)
    }

    @Test("The view holds the keyboard as soon as the window exists")
    func viewIsFirstResponder() throws {
        let (window, view) = try window(Self.frozen())
        #expect(window.firstResponder === view)
    }

    @Test("The view takes the click that makes the application active")
    func takesFirstMouse() throws {
        let (_, view) = try window(Self.frozen())
        #expect(view.acceptsFirstMouse(for: nil))
    }

    @Test("A drag put into the window chooses a region")
    func dragThroughTheWindow() throws {
        let (window, view) = try window(Self.frozen())
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let top = Self.height - 120
        window.sendEvent(try event(.leftMouseDown, at: NSPoint(x: 100, y: top), in: window))
        window.sendEvent(try event(.leftMouseDragged, at: NSPoint(x: 400, y: top - 200), in: window))
        window.sendEvent(try event(.leftMouseUp, at: NSPoint(x: 400, y: top - 200), in: window))

        #expect(
            view.overlay.outcome
                == .region(ScreenRect(Rect(x: 100, y: 120, width: 300, height: 200))))
    }

    @Test("A drag on a window for a display away from the origin chooses a region there")
    func dragOnASecondDisplay() throws {
        let (window, view) = try window(Self.frozen(at: P2(x: -1920, y: -600)))
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        let top = Self.height - 120
        window.sendEvent(try event(.leftMouseDown, at: NSPoint(x: 100, y: top), in: window))
        window.sendEvent(try event(.leftMouseDragged, at: NSPoint(x: 400, y: top - 200), in: window))
        window.sendEvent(try event(.leftMouseUp, at: NSPoint(x: 400, y: top - 200), in: window))

        #expect(
            view.overlay.outcome
                == .region(ScreenRect(Rect(x: -1820, y: -480, width: 300, height: 200))))
    }

    @Test("Escape put into the window cancels")
    func escapeThroughTheWindow() throws {
        let (window, view) = try window(Self.frozen())
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        window.cancelOperation(nil)
        #expect(view.overlay.outcome == .cancelled)
    }

    @Test("The view covers the window it is in")
    func viewFillsTheWindow() throws {
        let (window, view) = try window(Self.frozen())
        #expect(view.frame.size == window.contentView?.frame.size)
        #expect(view.frame.origin == NSPoint.zero)
    }

    @Test("The window covers the screen it was given")
    func windowCoversItsScreen() throws {
        let screen = try #require(NSScreen.main)
        let (window, _) = try window(Self.frozen())
        #expect(window.frame == screen.frame)
    }
}
