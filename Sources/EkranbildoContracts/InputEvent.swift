import EkranbildoGeometry

public struct Modifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)

    public static let plain: Self = []
}

public enum KeyCode: String, Hashable, Sendable, Codable {
    case escape
    case delete
    case enter
    case tab
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
}

public enum ToolID: String, Hashable, Sendable, Codable {
    case select
    case annotate
    case redact
}

public enum InputEvent: Hashable, Sendable, Codable {
    case pointerDown(ScenePoint, Modifiers)
    case pointerMoved(ScenePoint, Modifiers)
    case pointerUp(ScenePoint, Modifiers)
    case pointerExited
    case key(KeyCode, Modifiers)
    case typed(String)
    case toolSelected(ToolID)
    case undo
    case redo
    case widen
}

public enum HistoryStep: Hashable, Sendable, CaseIterable {
    case back
    case forward
}

public enum Handling: Hashable, Sendable {
    case history(HistoryStep)
    case theEditor
}

extension InputEvent {
    public var handledBy: Handling {
        switch self {
        case .undo: .history(.back)
        case .redo: .history(.forward)
        case .pointerDown, .pointerMoved, .pointerUp, .pointerExited,
            .key, .typed, .toolSelected, .widen:
            .theEditor
        }
    }
}

public enum Arrow: Hashable, Sendable, CaseIterable {
    case up
    case down
    case left
    case right

    public func step(_ distance: Double) -> P2 {
        switch self {
        case .up: P2(x: 0, y: -distance)
        case .down: P2(x: 0, y: distance)
        case .left: P2(x: -distance, y: 0)
        case .right: P2(x: distance, y: 0)
        }
    }
}

extension KeyCode {
    public var arrow: Arrow? {
        switch self {
        case .arrowUp: .up
        case .arrowDown: .down
        case .arrowLeft: .left
        case .arrowRight: .right
        case .escape, .delete, .enter, .tab: nil
        }
    }
}
