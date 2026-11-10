import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public enum Drag: Hashable, Sendable {
    case idle
    case moving(AnnotationID, HitResult, from: ScenePoint)
    case marquee(from: ScenePoint, to: ScenePoint)
    case placing(from: ScenePoint, to: ScenePoint)
}

public struct Typing: Hashable, Sendable {
    public let annotation: AnnotationID
    public var text: String
    public let wasNamed: String?

    public init(annotation: AnnotationID, text: String, wasNamed: String?) {
        self.annotation = annotation
        self.text = text
        self.wasNamed = wasNamed
    }

    public var isNew: Bool { wasNamed == nil }
}

public struct EditorState: Hashable, Sendable {
    public var scene: Scene
    public var tool: ToolID
    public var selection: [AnnotationID]
    public var drag: Drag
    public var hovered: HitResult
    public var typing: Typing?

    public init(
        scene: Scene,
        tool: ToolID = .select,
        selection: [AnnotationID] = [],
        drag: Drag = .idle,
        hovered: HitResult = .nothing,
        typing: Typing? = nil
    ) {
        self.scene = scene
        self.tool = tool
        self.selection = selection
        self.drag = drag
        self.hovered = hovered
        self.typing = typing
    }

    public var isDragging: Bool { drag != .idle }
}

public enum EditorCommand: Hashable, Sendable {
    case addAnnotation(target: SceneRect, label: String)
    case removeAnnotations([AnnotationID])
    case moveTarget(AnnotationID, to: SceneRect)
    case setPlacement(AnnotationID, Placement)
    case setLabel(AnnotationID, String)
    case hide(Mask)
    case number(AnnotationID)
    case solve
}

public enum EditorEffect: Hashable, Sendable {
    case refused(String)
    case checkpoint
}
