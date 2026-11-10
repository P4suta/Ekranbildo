import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLayout

public struct Document: Sendable {
    public private(set) var scene: Scene
    private let measurer: any TextMeasuring
    private let historyLimit: Int

    private var past: [Scene] = []
    private var future: [Scene] = []

    public init(
        scene: Scene,
        measurer: any TextMeasuring,
        historyLimit: Int = Defaults.historyLimit
    ) {
        self.scene = scene
        self.measurer = measurer
        self.historyLimit = max(1, historyLimit)
    }

    public enum Defaults {
        public static let historyLimit = 50
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    public mutating func checkpoint() {
        past.append(scene)
        if past.count > historyLimit {
            past.removeFirst(past.count - historyLimit)
        }
        future.removeAll()
    }

    public mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(scene)
        scene = previous
    }

    public mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(scene)
        scene = next
    }

    public mutating func apply(_ commands: [EditorCommand]) {
        for command in commands {
            apply(command)
        }
    }

    private mutating func apply(_ command: EditorCommand) {
        switch command {
        case .addAnnotation(let target, let label):
            scene = replacing(
                scene.annotations
                    + [
                        Annotation(
                            id: Self.nextID(in: scene),
                            target: target,
                            label: label,
                            placement: nil
                        )
                    ]
            )

        case .removeAnnotations(let ids):
            scene = replacing(
                Self.closingGaps(scene.annotations.filter { !ids.contains($0.id) }))

        case .moveTarget(let id, let target):
            scene = replacing(
                scene.annotations.map { annotation in
                    guard annotation.id == id else { return annotation }
                    return annotation.replacing(
                        target: target, placement: .some(nil), pinned: false)
                }
            )

        case .setPlacement(let id, let placement):
            scene = replacing(
                scene.annotations.map { annotation in
                    guard annotation.id == id else { return annotation }
                    return annotation.replacing(placement: placement, pinned: true)
                }
            )

        case .setLabel(let id, let label):
            scene = replacing(
                scene.annotations.map { annotation in
                    guard annotation.id == id else { return annotation }
                    return annotation.replacing(label: label)
                }
            )

        case .number(let id):
            number(id)

        case .hide(let mask):
            scene = replacing(masks: scene.masks + [mask])

        case .solve:
            solve()
        }
    }

    private mutating func solve() {
        guard !scene.annotations.isEmpty else { return }

        let solution = ExactSolver().solve(
            LayoutProblem(
                canvas: scene.canvas,
                style: scene.style,
                annotations: scene.annotations,
                measurer: measurer
            ),
            budget: .standard
        )
        scene = replacing(solution.applied(to: scene.annotations))
    }

    private func replacing(_ annotations: [Annotation]) -> Scene {
        scene.replacing(annotations: annotations)
    }

    private func replacing(masks: [Mask]) -> Scene {
        scene.replacing(masks: masks)
    }

    private mutating func number(_ id: AnnotationID) {
        guard let annotation = scene.annotations.first(where: { $0.id == id }) else { return }
        scene = replacing(
            Self.renumbered(
                scene.annotations,
                setting: id,
                to: annotation.badge == nil ? Self.nextBadge(in: scene) : nil
            )
        )
    }

    static func nextBadge(in scene: Scene) -> BadgeNumber {
        BadgeNumber((scene.annotations.compactMap { $0.badge?.value }.max() ?? 0) + 1)
    }

    static func renumbered(
        _ annotations: [Annotation],
        setting id: AnnotationID,
        to badge: BadgeNumber?
    ) -> [Annotation] {
        let changed = annotations.map { annotation in
            annotation.id == id ? annotation.replacing(badge: .some(badge)) : annotation
        }
        return closingGaps(changed)
    }

    static func closingGaps(_ annotations: [Annotation]) -> [Annotation] {
        let order =
            annotations
            .compactMap { annotation in annotation.badge.map { (annotation.id, $0) } }
            .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
        var given: Lookup<AnnotationID, BadgeNumber> = Lookup()
        for (position, pair) in order.enumerated() {
            given[pair.0] = BadgeNumber(position + 1)
        }
        return annotations.map { annotation in
            guard let badge = given[annotation.id] else { return annotation }
            return annotation.replacing(badge: .some(badge))
        }
    }

    static func nextID(in scene: Scene) -> AnnotationID {
        AnnotationID((scene.annotations.map(\.id.raw).max() ?? 0) + 1)
    }
}
