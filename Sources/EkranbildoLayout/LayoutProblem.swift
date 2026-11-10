import EkranbildoContracts
import EkranbildoCore
import EkranbildoField
import EkranbildoGeometry

public enum CandidateTag: Sendable {}
public typealias CandidateID = StableID<CandidateTag>

public struct LayoutCandidate: Hashable, Sendable, Identifiable {
    public let id: CandidateID
    public let annotationID: AnnotationID
    public let annotationIndex: Int
    public let placement: Placement
    public let tip: ScenePoint
    public let tail: ScenePoint
    public let labelRect: SceneRect
    public let leader: Polyline

    public init(
        id: CandidateID,
        annotationID: AnnotationID,
        annotationIndex: Int,
        placement: Placement,
        tip: ScenePoint,
        tail: ScenePoint,
        labelRect: SceneRect
    ) {
        self.id = id
        self.annotationID = annotationID
        self.annotationIndex = annotationIndex
        self.placement = placement
        self.tip = tip
        self.tail = tail
        self.labelRect = labelRect
        leader = Polyline(points: [tail.raw, tip.raw])
    }
}

public struct LayoutProblem: Sendable {
    public let canvas: SceneRect
    public let style: StyleTokens
    public let annotations: [Annotation]
    public let textSizes: [Size]
    public let field: OccupancyField

    public let elements: [ScreenElement]

    public let saliency: SaliencyMap

    public let reading: ReadingDirection

    public init(
        canvas: SceneRect,
        style: StyleTokens,
        annotations: [Annotation],
        measurer: any TextMeasuring,
        semantics: SceneSemantics,
        reading: ReadingDirection = .leftToRight,
        field: OccupancyField? = nil
    ) {
        self.init(
            canvas: canvas,
            style: style,
            annotations: annotations,
            measurer: measurer,
            elements: semantics.elements,
            saliency: semantics.saliency,
            reading: reading,
            field: field
        )
    }

    public init(
        canvas: SceneRect,
        style: StyleTokens,
        annotations: [Annotation],
        measurer: any TextMeasuring,
        elements: [ScreenElement] = [],
        saliency: SaliencyMap = .empty,
        reading: ReadingDirection = .leftToRight,
        field: OccupancyField? = nil
    ) {
        self.canvas = canvas
        self.style = style
        self.annotations = annotations
        self.elements = elements
        self.saliency = saliency
        self.reading = reading
        textSizes = annotations.map {
            LabelMetrics.size(of: $0, style: style, measurer: measurer)
        }
        self.field =
            field
            ?? Self.buildField(
                canvas: canvas,
                annotations: annotations,
                elements: elements,
                saliency: saliency
            )
    }

    private static func buildField(
        canvas: SceneRect,
        annotations: [Annotation],
        elements: [ScreenElement],
        saliency: SaliencyMap
    ) -> OccupancyField {
        var builder = OccupancyFieldBuilder(canvas: canvas)
        for annotation in annotations {
            builder.add(annotation.target, weight: Weights.target, to: .elements)
        }
        for element in elements {
            guard element.rect.raw.area < canvas.raw.area * Weights.backgroundFraction else {
                continue
            }
            builder.add(
                element.rect,
                weight: element.confidence * Weights.forCovering(element.kind),
                to: element.kind == .text ? .textInk : .elements
            )
        }
        addSaliency(saliency, canvas: canvas, to: &builder)
        return builder.build()
    }

    private static func addSaliency(
        _ saliency: SaliencyMap,
        canvas: SceneRect,
        to builder: inout OccupancyFieldBuilder
    ) {
        guard saliency.isWellFormed else { return }
        let cellWidth = canvas.raw.width / Double(saliency.columns)
        let cellHeight = canvas.raw.height / Double(saliency.rows)
        for row in 0..<saliency.rows {
            for column in 0..<saliency.columns {
                builder.add(
                    SceneRect(
                        x: canvas.minX + Double(column) * cellWidth,
                        y: canvas.minY + Double(row) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    ),
                    weight: saliency[column: column, row: row] * Weights.saliency,
                    to: .saliency
                )
            }
        }
    }

    private enum Weights {
        static let target: Double = 1
        static let detectedElement: Double = 0.7
        static let backgroundFraction: Double = 0.5
        static let text: Double = 0.9
        static let saliency: Double = 0.5

        static func forCovering(_ kind: ScreenElement.Kind) -> Double {
            switch kind {
            case .text: text
            case .surface, .canvas: detectedElement
            }
        }
    }

    public var targets: [SceneRect] { annotations.map(\.target) }

    public var readingOrder: [Int] {
        annotations.indices.sorted { first, second in
            let a = annotations[first].target
            let b = annotations[second].target
            guard a.minY != b.minY else {
                return reading == .leftToRight ? a.minX < b.minX : a.minX > b.minX
            }
            return a.minY < b.minY
        }
    }
}

extension LayoutProblem {
    public func scene(showing annotations: [Annotation]) -> Scene {
        Scene(
            canvas: canvas,
            background: nil,
            annotations: annotations,
            style: style
        )
    }
}
