import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoRender
import EkranbildoRenderCoreGraphics

@MainActor
public final class CanvasLayerView: NSView {
    public var drawing: DrawList? {
        didSet { needsDisplay = true }
    }
    public var warn: (@MainActor ([RenderWarning]) -> Void)?
    public var assets: (any AssetStoring)?

    override public var isOpaque: Bool { false }

    override public func draw(_ dirty: NSRect) {
        guard let drawing, !drawing.commands.isEmpty else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let warnings = CoreGraphicsRenderer(assets: assets)
            .draw(drawing, into: context, scale: 1)
        if !warnings.isEmpty { warn?(warnings) }
    }
}

@MainActor
public final class CanvasView: NSView {
    public var scene: Scene {
        didSet { rebuild() }
    }
    public private(set) var moving: [AnnotationID] = []
    private let assets: (any AssetStoring)?

    private let background = CanvasLayerView()
    private let still = CanvasLayerView()
    private let active = CanvasLayerView()

    public init(scene: Scene, assets: (any AssetStoring)? = nil) {
        self.scene = scene
        self.assets = assets
        super.init(
            frame: NSRect(
                origin: .zero,
                size: NSSize(width: scene.canvas.width, height: scene.canvas.height)))
        for layer in [background, still, active] {
            layer.assets = assets
            layer.autoresizingMask = [.width, .height]
            layer.frame = bounds
            addSubview(layer)
        }
        rebuild()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { nil }

    public var send: (@MainActor (InputEvent) -> Void)?

    override public var acceptsFirstResponder: Bool { true }

    override public func mouseDown(with event: NSEvent) {
        send?(.pointerDown(point(of: event), Self.modifiers(of: event)))
    }

    override public func mouseDragged(with event: NSEvent) {
        send?(.pointerMoved(point(of: event), Self.modifiers(of: event)))
    }

    override public func mouseUp(with event: NSEvent) {
        send?(.pointerUp(point(of: event), Self.modifiers(of: event)))
    }

    override public func mouseExited(with event: NSEvent) {
        send?(.pointerExited)
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        let pressed = event.charactersIgnoringModifiers?.lowercased()
        let shifted = event.modifierFlags.contains(.shift)
        switch (pressed, shifted) {
        case ("z", false):
            send?(.undo)
        case ("z", true), ("y", false):
            send?(.redo)
        default:
            return false
        }
        return true
    }

    override public func keyDown(with event: NSEvent) {
        if let key = Self.key(of: event) {
            send?(.key(key, Self.modifiers(of: event)))
            return
        }
        guard !event.modifierFlags.contains(.command),
            let typed = event.characters,
            !typed.isEmpty,
            typed.allSatisfy({ !$0.isNewline && $0.unicodeScalars.allSatisfy(Self.isTypable) })
        else {
            super.keyDown(with: event)
            return
        }
        send?(.typed(typed))
    }

    private static func isTypable(_ scalar: Unicode.Scalar) -> Bool {
        !CharacterSet.controlCharacters.contains(scalar)
            && !Keys.privateUse.contains(scalar.value)
    }

    private func point(of event: NSEvent) -> ScenePoint {
        let local = convert(event.locationInWindow, from: nil)
        return ScenePoint(x: local.x, y: bounds.height - local.y)
    }

    private static func key(of event: NSEvent) -> KeyCode? {
        switch event.keyCode {
        case Keys.escape: .escape
        case Keys.delete: .delete
        case Keys.left: .arrowLeft
        case Keys.right: .arrowRight
        case Keys.up: .arrowUp
        case Keys.down: .arrowDown
        case Keys.returnKey, Keys.enterKey: .enter
        case Keys.tab: .tab
        default: nil
        }
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
        static let delete: UInt16 = 51
        static let left: UInt16 = 123
        static let right: UInt16 = 124
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let returnKey: UInt16 = 36
        static let enterKey: UInt16 = 76
        static let tab: UInt16 = 48
        static let privateUse: ClosedRange<UInt32> = 0xF700...0xF8FF
    }

    public func beginMoving(_ annotations: [AnnotationID]) {
        moving = annotations
        rebuild()
    }

    public func endMoving() {
        moving = []
        rebuild()
    }

    private func rebuild() {
        let layered = DrawListBuilder(measurer: TabulatedTextMeasurer.uniform())
            .layered(scene, moving: moving)
        background.drawing = layered.drawing(of: layered.background)
        still.drawing = layered.drawing(of: layered.still)
        active.drawing = layered.drawing(of: layered.moving)
    }
}
