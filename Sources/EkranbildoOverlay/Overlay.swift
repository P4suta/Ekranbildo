import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoSemantics

public struct FrozenScreen: Sendable {
    public let display: DisplayGeometry
    public let image: ImageBuffer
    public let windows: WindowStack

    public init(display: DisplayGeometry, image: ImageBuffer, windows: WindowStack) {
        self.display = display
        self.image = image
        self.windows = windows
    }
}

public enum OverlayOutcome: Hashable, Sendable {
    case region(ScreenRect)
    case window(WindowID)
    case display(UInt32)
    case cancelled
}

public struct Overlay: Sendable {
    public let frozen: FrozenScreen
    public private(set) var highlighted: WindowDescriptor?
    public private(set) var selection: ScreenRect?
    public private(set) var outcome: OverlayOutcome?
    public private(set) var snapped: SceneRect?

    private var elements: [ScreenElement] = []
    private var ladder: [SceneRect] = []
    private var rung = 0

    private var pressedAt: ScreenPoint?
    private let snapDistance: Double
    private let minimumRegion: Double

    public init(
        frozen: FrozenScreen,
        snapDistance: Double = Defaults.snapDistance,
        minimumRegion: Double = Defaults.minimumRegion
    ) {
        self.frozen = frozen
        self.snapDistance = snapDistance
        self.minimumRegion = minimumRegion
    }

    public enum Defaults {
        public static let snapDistance: Double = 8
        public static let minimumRegion: Double = 4
    }

    public func handle(_ event: InputEvent) -> Self {
        guard outcome == nil else { return self }

        switch event {
        case .pointerMoved(let point, let modifiers):
            return moved(to: screenPoint(point), modifiers)
        case .pointerDown(let point, _):
            var next = self
            next.pressedAt = screenPoint(point)
            return next
        case .pointerUp(let point, let modifiers):
            return released(at: screenPoint(point), modifiers)
        case .key(let key, _):
            return pressed(key)
        case .widen:
            return widened()
        case .pointerExited, .typed, .toolSelected, .undo, .redo:
            return self
        }
    }

    public mutating func learned(_ elements: [ScreenElement]) {
        self.elements = elements
    }

    private func widened() -> Self {
        guard rung + 1 < ladder.count else { return self }
        var next = self
        next.rung += 1
        next.snapped = ladder[next.rung]
        return next
    }

    private func snapping(to point: ScenePoint) -> (ladder: [SceneRect], snapped: SceneRect?) {
        guard !elements.isEmpty else { return ([], nil) }
        let found = TargetSnapper().targets(among: elements, at: point)
        return (found, found.first)
    }

    private func moved(to screen: ScreenPoint, _ modifiers: Modifiers) -> Self {
        var next = self
        guard let pressed = pressedAt else {
            next.highlighted = frozen.windows.window(under: screen)
            let found = snapping(to: inDisplay(screen))
            next.ladder = found.ladder
            next.rung = 0
            next.snapped = found.snapped
            return next
        }
        next.selection = region(from: pressed, to: screen, modifiers: modifiers)
        return next
    }

    private func released(at screen: ScreenPoint, _ modifiers: Modifiers) -> Self {
        var next = self
        guard let pressed = pressedAt else { return next }
        next.pressedAt = nil

        let swept = region(from: pressed, to: screen, modifiers: modifiers)
        guard swept.raw.width < minimumRegion || swept.raw.height < minimumRegion else {
            next.selection = swept
            next.outcome = .region(swept)
            return next
        }

        next.selection = nil
        if let snapped = snapped ?? snapping(to: inDisplay(screen)).snapped {
            next.outcome = .region(ScreenRect(fromDisplay(snapped)))
            return next
        }
        if let window = frozen.windows.window(under: screen) {
            next.outcome = .window(window.id)
        }
        return next
    }

    private func inDisplay(_ screen: ScreenPoint) -> ScenePoint {
        ScenePoint(
            x: screen.x - frozen.display.bounds.minX,
            y: screen.y - frozen.display.bounds.minY
        )
    }

    private func fromDisplay(_ rect: SceneRect) -> Rect {
        Rect(
            x: rect.minX + frozen.display.bounds.minX,
            y: rect.minY + frozen.display.bounds.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private func pressed(_ key: KeyCode) -> Self {
        var next = self
        switch key {
        case .escape:
            next.pressedAt = nil
            next.selection = nil
            next.outcome = .cancelled
        case .enter:
            next.outcome = .display(frozen.display.displayID)
        case .delete, .tab, .arrowUp, .arrowDown, .arrowLeft, .arrowRight:
            break
        }
        return next
    }

    private func region(
        from: ScreenPoint,
        to: ScreenPoint,
        modifiers: Modifiers
    ) -> ScreenRect {
        let swept = ScreenRect(
            x: min(from.x, to.x),
            y: min(from.y, to.y),
            width: abs(to.x - from.x),
            height: abs(to.y - from.y)
        )
        guard !modifiers.contains(.option) else { return swept }
        return frozen.windows.snap(swept, within: snapDistance)
    }

    private func screenPoint(_ point: ScenePoint) -> ScreenPoint {
        ScreenPoint(
            x: point.x + frozen.display.bounds.minX,
            y: point.y + frozen.display.bounds.minY
        )
    }
}

extension Overlay {
    public static func screenUnder(_ pointer: ScreenPoint, among screens: [ScreenRect]) -> Int? {
        guard !screens.isEmpty else { return nil }
        return screens.firstIndex { $0.raw.contains(pointer.raw) } ?? 0
    }
}
