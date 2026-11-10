import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry

public struct AccessibleElement: Hashable, Sendable {
    public let id: AnnotationID
    public let label: String
    public let frame: SceneRect

    public init(id: AnnotationID, label: String, frame: SceneRect) {
        self.id = id
        self.label = label
        self.frame = frame
    }
}

public struct AccessibilityDescription: Sendable {
    private let measurer: any TextMeasuring

    public init(measurer: any TextMeasuring) {
        self.measurer = measurer
    }

    public func elements(of scene: Scene) -> [AccessibleElement] {
        scene.annotations
            .compactMap { annotation -> AccessibleElement? in
                guard let placement = annotation.placement else { return nil }

                let resolved = ResolvedPlacement(
                    target: annotation.target,
                    placement: placement,
                    style: scene.style
                )
                let plate = resolved.labelBox(
                    textSize: LabelMetrics.size(
                        of: annotation, style: scene.style, measurer: measurer),
                    style: scene.style
                )

                return AccessibleElement(
                    id: annotation.id,
                    label: Self.spoken(annotation),
                    frame: Self.enclosing([plate, annotation.target, Self.around(resolved.tip)])
                )
            }
            .sorted {
                ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX)
            }
    }

    static func spoken(_ annotation: Annotation) -> String {
        let words = annotation.label.isEmpty ? Phrases.unnamed : annotation.label
        guard let badge = annotation.badge else { return words }
        return "\(Phrases.step) \(badge.value): \(words)"
    }

    private static func around(_ point: ScenePoint) -> SceneRect {
        SceneRect(x: point.x, y: point.y, width: 0, height: 0)
    }

    private static func enclosing(_ rects: [SceneRect]) -> SceneRect {
        guard let first = rects.first else { return SceneRect(x: 0, y: 0, width: 0, height: 0) }
        var minX = first.minX
        var minY = first.minY
        var maxX = first.maxX
        var maxY = first.maxY
        for rect in rects.dropFirst() {
            minX = min(minX, rect.minX)
            minY = min(minY, rect.minY)
            maxX = max(maxX, rect.maxX)
            maxY = max(maxY, rect.maxY)
        }
        return SceneRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private enum Phrases {
        static let unnamed = "Unnamed annotation"
        static let step = "Step"
    }
}
