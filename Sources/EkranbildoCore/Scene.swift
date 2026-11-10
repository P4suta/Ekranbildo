import EkranbildoContracts
import EkranbildoGeometry
import Foundation

public enum AnnotationTag: Sendable {}
public typealias AnnotationID = StableID<AnnotationTag>

public struct Placement: Hashable, Sendable, Codable {
    public let direction: Direction16
    public let leaderLength: Double

    public init(direction: Direction16, leaderLength: Double) {
        self.direction = direction
        self.leaderLength = leaderLength
    }
}

public struct Annotation: Hashable, Sendable, Codable, Identifiable {
    public let id: AnnotationID
    public let target: SceneRect
    public let label: String
    public let placement: Placement?
    public let isPinned: Bool
    public let badge: BadgeNumber?

    public init(
        id: AnnotationID,
        target: SceneRect,
        label: String,
        placement: Placement?,
        badge: BadgeNumber? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.target = target
        self.label = label
        self.placement = placement
        self.badge = badge
        self.isPinned = isPinned
    }

    public func replacing(
        target: SceneRect? = nil,
        label: String? = nil,
        placement: Placement?? = nil,
        badge: BadgeNumber?? = nil,
        pinned: Bool? = nil
    ) -> Self {
        Self(
            id: id,
            target: target ?? self.target,
            label: label ?? self.label,
            placement: placement ?? self.placement,
            badge: badge ?? self.badge,
            isPinned: pinned ?? isPinned
        )
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AnnotationID.self, forKey: .id)
        target = try container.decode(SceneRect.self, forKey: .target)
        label = try container.decode(String.self, forKey: .label)
        placement = try container.decodeIfPresent(Placement.self, forKey: .placement)
        badge = try container.decodeIfPresent(BadgeNumber.self, forKey: .badge)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}

public struct BadgeNumber: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public init(from decoder: any Decoder) throws {
        value = try decoder.singleValueContainer().decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public static func < (a: Self, b: Self) -> Bool { a.value < b.value }
    public var description: String { "\(value)" }
}

public struct Scene: Hashable, Sendable, Codable {
    public let canvas: SceneRect
    public let background: ImageRef?
    public let annotations: [Annotation]
    public let masks: [Mask]
    public let style: StyleTokens
    public let cursor: Cursor?
    public let keys: [String]
    public let unknownKeys: UnknownKeys

    public init(
        canvas: SceneRect,
        background: ImageRef?,
        annotations: [Annotation],
        style: StyleTokens,
        masks: [Mask] = [],
        cursor: Cursor? = nil,
        keys: [String] = [],
        unknownKeys: UnknownKeys = .nothing
    ) {
        self.canvas = canvas
        self.background = background
        self.annotations = annotations
        self.masks = masks
        self.style = style
        self.cursor = cursor
        self.keys = keys
        self.unknownKeys = unknownKeys
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        canvas = try container.decode(SceneRect.self, forKey: .canvas)
        background = try container.decodeIfPresent(ImageRef.self, forKey: .background)
        annotations = try container.decodeIfPresent([Annotation].self, forKey: .annotations) ?? []
        masks = try container.decodeIfPresent([Mask].self, forKey: .masks) ?? []
        style = try container.decodeIfPresent(StyleTokens.self, forKey: .style) ?? .standard
        cursor = try container.decodeIfPresent(Cursor.self, forKey: .cursor)
        keys = try container.decodeIfPresent([String].self, forKey: .keys) ?? []
        unknownKeys = try UnknownKeys.read(
            from: decoder, known: NameSet(CodingKeys.allCases.map(\.rawValue)))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(canvas, forKey: .canvas)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encode(annotations, forKey: .annotations)
        try container.encode(masks, forKey: .masks)
        try container.encode(style, forKey: .style)
        try container.encodeIfPresent(cursor, forKey: .cursor)
        try container.encode(keys, forKey: .keys)
        try unknownKeys.write(to: encoder)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case canvas, background, annotations, masks, style, cursor, keys
    }
}

public struct ResolvedPlacement: Hashable, Sendable {
    public let tip: ScenePoint
    public let tail: ScenePoint
    public let direction: Direction16

    public init(target: SceneRect, placement: Placement, style: StyleTokens) {
        let outward = placement.direction.unit
        let center = target.raw.center

        let distanceToTip =
            BoxGeometry.distanceFromCenterToBorder(
                size: target.size,
                direction: placement.direction
            ) + style.tipGap

        let tipPoint = P2(
            x: center.x + outward.x * distanceToTip,
            y: center.y + outward.y * distanceToTip
        )
        let tailPoint = P2(
            x: tipPoint.x + outward.x * placement.leaderLength,
            y: tipPoint.y + outward.y * placement.leaderLength
        )

        tip = ScenePoint(tipPoint)
        tail = ScenePoint(tailPoint)
        direction = placement.direction
    }

    public var leader: Polyline {
        Polyline(points: [tail.raw, tip.raw])
    }

    public func labelBox(textSize: Size, style: StyleTokens) -> SceneRect {
        let size = Size(
            width: textSize.width + 2 * style.labelPaddingHorizontal,
            height: textSize.height + 2 * style.labelPaddingVertical
        )
        let outward = direction.unit
        let toEdge = BoxGeometry.distanceFromCenterToBorder(size: size, direction: direction)
        let center = P2(x: tail.x + outward.x * toEdge, y: tail.y + outward.y * toEdge)
        return SceneRect(
            x: center.x - Geo.half(size.width),
            y: center.y - Geo.half(size.height),
            width: size.width,
            height: size.height
        )
    }

    public func labelBaseline(
        metrics: TextMetrics,
        style: StyleTokens,
        textSize: Size? = nil
    ) -> ScenePoint {
        let size = textSize ?? Size(width: metrics.width, height: metrics.height)
        let box = labelBox(textSize: size, style: style)
        return ScenePoint(
            x: box.minX + style.labelPaddingHorizontal,
            y: box.raw.center.y - Geo.half(metrics.height) + metrics.ascent
        )
    }
}

public enum LabelMetrics {

    public static func size(
        of annotation: Annotation,
        style: StyleTokens,
        measurer: any TextMeasuring
    ) -> Size {
        let text = measurer.measure(annotation.label, font: style.labelFont)
        let extra = annotation.badge == nil ? 0 : badgeAllowance(style: style)
        return Size(
            width: text.width + extra,
            height: max(text.height, annotation.badge == nil ? 0 : style.badgeDiameter)
        )
    }

    public static func badgeAllowance(style: StyleTokens) -> Double {
        style.badgeDiameter + style.badgeGap
    }
}

public enum BoxGeometry {

    public static func distanceFromCenterToBorder(size: Size, direction: Direction16) -> Double {
        let outward = direction.unit
        let halfWidth = Geo.half(size.width)
        let halfHeight = Geo.half(size.height)
        let horizontal = outward.x == 0 ? Double.infinity : halfWidth / abs(outward.x)
        let vertical = outward.y == 0 ? Double.infinity : halfHeight / abs(outward.y)
        let toBorder = min(horizontal, vertical)
        return toBorder.isFinite ? toBorder : 0
    }
}

extension Scene {
    public func replacing(
        annotations: [Annotation]? = nil,
        background: ImageRef?? = nil,
        masks: [Mask]? = nil,
        cursor: Cursor?? = nil,
        keys: [String]? = nil,
        unknownKeys: UnknownKeys? = nil
    ) -> Self {
        Self(
            canvas: canvas,
            background: background ?? self.background,
            annotations: annotations ?? self.annotations,
            style: style,
            masks: masks ?? self.masks,
            cursor: cursor ?? self.cursor,
            keys: keys ?? self.keys,
            unknownKeys: unknownKeys ?? self.unknownKeys
        )
    }
}
