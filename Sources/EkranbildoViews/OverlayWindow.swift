import AppKit
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoOverlay
import EkranbildoRenderCoreGraphics

@MainActor
public final class OverlayView: NSView {
    public var overlay: Overlay {
        didSet { needsDisplay = true }
    }
    private let assets: any AssetStoring

    public init(overlay: Overlay, assets: any AssetStoring) {
        self.overlay = overlay
        self.assets = assets
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: overlay.frozen.display.bounds.width,
                height: overlay.frozen.display.bounds.height
            ))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    override public var isOpaque: Bool { true }

    override public var acceptsFirstResponder: Bool { true }

    override public func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public var drew: (@MainActor (String) -> Void)?

    override public func draw(_ dirty: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            drew?("asked to draw with no context")
            return
        }
        let list = overlay.drawList
        drew?(
            "drawing \(list.commands.count) command(s) over "
                + "\(Int(dirty.width))x\(Int(dirty.height))"
        )
        let warnings = CoreGraphicsRenderer(assets: assets)
            .draw(list, into: context, scale: 1)
        drew?(
            "drew \(list.commands.count) command(s)"
                + (warnings.isEmpty
                    ? ""
                    : ", with \(warnings.count) it could not do exactly: "
                        + warnings.map(\.detail).joined(separator: "; "))
        )
    }

    public var send: (@MainActor (InputEvent) -> Void)?

    public var arrived: (@MainActor (String) -> Void)?

    override public func mouseDown(with event: NSEvent) {
        let pressed = point(of: event)
        arrived?(
            "pressed at (\(Int(pressed.x)), \(Int(pressed.y))) in a view "
                + "\(Int(bounds.width))x\(Int(bounds.height)) over a display "
                + "\(Int(overlay.frozen.display.bounds.width))x"
                + "\(Int(overlay.frozen.display.bounds.height))"
        )
        send?(.pointerDown(pressed, Self.modifiers(of: event)))
    }

    override public func mouseDragged(with event: NSEvent) {
        send?(.pointerMoved(point(of: event), Self.modifiers(of: event)))
    }

    override public func mouseUp(with event: NSEvent) {
        send?(.pointerUp(point(of: event), Self.modifiers(of: event)))
    }

    override public func mouseMoved(with event: NSEvent) {
        send?(.pointerMoved(point(of: event), Self.modifiers(of: event)))
    }

    override public func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case Keys.escape:
            send?(.key(.escape, Self.modifiers(of: event)))
        case Keys.space:
            send?(.widen)
        case Keys.returnKey, Keys.enterKey:
            send?(.key(.enter, Self.modifiers(of: event)))
        default:
            break
        }
    }

    private func point(of event: NSEvent) -> ScenePoint {
        let local = convert(event.locationInWindow, from: nil)
        return ScenePoint(x: local.x, y: overlay.frozen.display.bounds.height - local.y)
    }

    private static func modifiers(of event: NSEvent) -> Modifiers {
        var modifiers: Modifiers = []
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }

    private enum Keys {
        static let escape: UInt16 = 53
        static let space: UInt16 = 49
        static let returnKey: UInt16 = 36
        static let enterKey: UInt16 = 76
    }
}

@MainActor
public final class OverlayWindow: NSWindow {
    public var overlay: Overlay { (contentView as? OverlayView)?.overlay ?? empty }

    private var empty: Overlay {
        Overlay(
            frozen: FrozenScreen(
                display: DisplayGeometry(displayID: 0, bounds: .zero, backingScale: 1),
                image: ImageBuffer(width: 0, height: 0, colorSpace: .displayP3, pixels: []),
                windows: WindowStack(windows: [])
            ))
    }

    public init(view: OverlayView, screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        contentView = view
        initialFirstResponder = view
        makeFirstResponder(view)
        level = Self.level
        isOpaque = true
        backgroundColor = .black
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        acceptsMouseMovedEvents = true
    }

    public static let level = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))

    override public var canBecomeKey: Bool { true }

    public var received: (@MainActor (String) -> Void)?

    override public func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .keyDown, .flagsChanged:
            let size =
                contentView.map { "\(Int($0.bounds.width))x\(Int($0.bounds.height))" } ?? "none"
            let hit = contentView?.hitTest(event.locationInWindow).map { "\(type(of: $0))" }
            received?(
                "window got \(event.type.rawValue) at "
                    + "(\(Int(event.locationInWindow.x)), \(Int(event.locationInWindow.y))); "
                    + "key=\(isKeyWindow), visible=\(isVisible), view=\(size), "
                    + "hit=\(hit ?? "nothing")"
            )
        default:
            break
        }
        super.sendEvent(event)
    }

    override public func cancelOperation(_ sender: Any?) {
        (contentView as? OverlayView)?.send?(.key(.escape, []))
    }
}
