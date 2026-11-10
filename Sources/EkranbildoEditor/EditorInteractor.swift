import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public struct EditorInteractor: Sendable {
    private let measurer: any TextMeasuring
    let nudge: Double
    let coarseNudge: Double
    private let dragThreshold: Double

    public init(
        measurer: any TextMeasuring,
        nudge: Double = Defaults.nudge,
        coarseNudge: Double = Defaults.coarseNudge,
        dragThreshold: Double = Defaults.dragThreshold
    ) {
        self.measurer = measurer
        self.nudge = nudge
        self.coarseNudge = coarseNudge
        self.dragThreshold = dragThreshold
    }

    public enum Defaults {
        public static let nudge: Double = 1
        public static let coarseNudge: Double = 10
        public static let dragThreshold: Double = 3
        public static let tapTargetRadius: Double = 8
        public static let shortestLeader: Double = 8
        public static let longestLeader: Double = 400
    }

    public struct Outcome: Sendable {
        public let state: EditorState
        public let commands: [EditorCommand]
        public let effects: [EditorEffect]
    }

    public func handle(_ event: InputEvent, in state: EditorState) -> Outcome {
        switch event {
        case .pointerDown(let point, let modifiers):
            pointerDown(point, modifiers, state)
        case .pointerMoved(let point, _):
            pointerMoved(point, state)
        case .pointerUp(let point, _):
            pointerUp(point, state)
        case .pointerExited:
            Outcome(state: Self.withHover(.nothing, state), commands: [], effects: [])
        case .key(let key, let modifiers):
            self.key(key, modifiers, state)
        case .typed(let text):
            typed(text, state)
        case .toolSelected(let tool):
            toolSelected(tool, state)
        case .widen, .undo, .redo:
            Outcome(state: state, commands: [], effects: [])
        }
    }

    func toolSelected(_ tool: ToolID, _ state: EditorState) -> Outcome {
        if let typing = state.typing {
            let finished = finishedTyping(typing, state)
            let after = toolSelected(tool, finished.state)
            return Outcome(
                state: after.state,
                commands: finished.commands + after.commands,
                effects: finished.effects + after.effects
            )
        }
        var next = state
        next.drag = .idle
        next.tool = tool
        return Outcome(state: next, commands: [], effects: [])
    }

    private func pointerDown(
        _ point: ScenePoint,
        _ modifiers: Modifiers,
        _ state: EditorState
    ) -> Outcome {
        var next = state
        next.hovered = .nothing

        if let typing = state.typing {
            let finished = finishedTyping(typing, state)
            let after = pointerDown(point, modifiers, finished.state)
            return Outcome(
                state: after.state,
                commands: finished.commands + after.commands,
                effects: finished.effects + after.effects
            )
        }

        guard state.tool == .select else {
            next.drag = .placing(from: point, to: point)
            return Outcome(state: next, commands: [], effects: [])
        }

        let hit = tester(state).hit(at: point)
        guard let id = hit.annotationID else {
            next.selection = modifiers.contains(.shift) ? state.selection : []
            next.drag = .marquee(from: point, to: point)
            return Outcome(state: next, commands: [], effects: [])
        }

        if modifiers.contains(.shift) {
            if let existing = next.selection.firstIndex(of: id) {
                next.selection.remove(at: existing)
                next.drag = .idle
                return Outcome(state: next, commands: [], effects: [])
            }
            next.selection.append(id)
        } else if !state.selection.contains(id) {
            next.selection = [id]
        }

        next.drag = .moving(id, hit, from: point)
        return Outcome(state: next, commands: [], effects: [])
    }

    private func pointerMoved(_ point: ScenePoint, _ state: EditorState) -> Outcome {
        var next = state
        switch state.drag {
        case .idle:
            next.hovered = tester(state).hit(at: point)
        case .moving:
            next.hovered = .nothing
        case .marquee(let from, _):
            next.hovered = .nothing
            next.drag = .marquee(from: from, to: point)
        case .placing(let from, _):
            next.hovered = .nothing
            next.drag = .placing(from: from, to: point)
        }
        return Outcome(state: next, commands: [], effects: [])
    }

    private func pointerUp(_ point: ScenePoint, _ state: EditorState) -> Outcome {
        var next = state
        next.drag = .idle

        switch state.drag {
        case .idle:
            return Outcome(state: next, commands: [], effects: [])

        case .moving(let id, let hit, let from):
            guard Self.travelled(from, point) > dragThreshold else {
                guard hit.isLabel else {
                    return Outcome(state: next, commands: [], effects: [])
                }
                return Outcome(state: naming(id, in: next), commands: [], effects: [])
            }
            return moved(id, hit, from: from, to: point, next)

        case .marquee(let from, _):
            guard Self.travelled(from, point) > dragThreshold else {
                return Outcome(state: next, commands: [], effects: [])
            }
            next.selection = Self.enclosed(by: Self.rect(from, point), in: state.scene)
            return Outcome(state: next, commands: [], effects: [])

        case .placing(let from, _) where state.tool == .redact:
            guard Self.travelled(from, point) > dragThreshold else {
                return Outcome(state: next, commands: [], effects: [])
            }
            return Outcome(
                state: next,
                commands: [.hide(Mask(rect: Self.rect(from, point), style: .pixelate))],
                effects: [.checkpoint]
            )

        case .placing(let from, _):
            let target =
                Self.travelled(from, point) > dragThreshold
                ? Self.rect(from, point)
                : Self.rect(
                    ScenePoint(
                        x: point.x - Defaults.tapTargetRadius,
                        y: point.y - Defaults.tapTargetRadius),
                    ScenePoint(
                        x: point.x + Defaults.tapTargetRadius,
                        y: point.y + Defaults.tapTargetRadius)
                )
            let named = Document.nextID(in: state.scene)
            return Outcome(
                state: namingSomethingNew(named, in: next),
                commands: [.addAnnotation(target: target, label: ""), .solve],
                effects: [.checkpoint]
            )
        }
    }

    private func moved(
        _ id: AnnotationID,
        _ hit: HitResult,
        from: ScenePoint,
        to point: ScenePoint,
        _ state: EditorState
    ) -> Outcome {
        guard let annotation = state.scene.annotations.first(where: { $0.id == id }) else {
            return Outcome(state: state, commands: [], effects: [])
        }

        switch hit {
        case .label:
            return Outcome(
                state: state,
                commands: [
                    .setPlacement(
                        id,
                        Self.placement(
                            of: annotation,
                            droppedAt: point,
                            style: state.scene.style
                        )
                    )
                ],
                effects: [.checkpoint]
            )

        case .target, .leader, .handle:
            let target = annotation.target
            let moved = SceneRect(
                x: target.minX + (point.x - from.x),
                y: target.minY + (point.y - from.y),
                width: target.raw.width,
                height: target.raw.height
            )
            return Outcome(
                state: state,
                commands: [.moveTarget(id, to: moved), .solve],
                effects: [.checkpoint]
            )

        case .nothing:
            return Outcome(state: state, commands: [], effects: [])
        }
    }

    private func tester(_ state: EditorState) -> HitTester {
        HitTester(scene: state.scene, measurer: measurer)
    }

    private static func withHover(_ hit: HitResult, _ state: EditorState) -> EditorState {
        var next = state
        next.hovered = hit
        return next
    }

    static func travelled(_ from: ScenePoint, _ to: ScenePoint) -> Double {
        Geo.distanceSquared(from.raw, to.raw).squareRoot()
    }

    static func rect(_ from: ScenePoint, _ to: ScenePoint) -> SceneRect {
        SceneRect(
            x: min(from.x, to.x),
            y: min(from.y, to.y),
            width: abs(to.x - from.x),
            height: abs(to.y - from.y)
        )
    }

    static func enclosed(by rect: SceneRect, in scene: Scene) -> [AnnotationID] {
        scene.annotations
            .filter { Geo.overlaps(rect.raw, $0.target.raw) }
            .map(\.id)
    }

    static func direction(of key: KeyCode, step: Double) -> P2 {
        key.arrow?.step(step) ?? P2(x: 0, y: 0)
    }
}
