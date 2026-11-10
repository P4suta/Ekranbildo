public enum Geo {
    public static func half(_ length: Double) -> Double { length / Halving.parts }

    public static func middleIndex(of count: Int) -> Int { count / Halving.cells }

    public static func centring(_ length: Double, in room: Double) -> Double {
        half(room - length)
    }

    public static let circleHandle =
        Handle.thirds * (Handle.diagonal.squareRoot() - Handle.unit)

    private enum Sides {
        static let opposite = 2.0
    }

    private enum Halving {
        static let parts = 2.0
        static let cells = 2
    }

    private enum Handle {
        static let numerator = 4.0
        static let denominator = 3.0
        static let thirds = numerator / denominator
        static let diagonal = 2.0
        static let unit = 1.0
    }

    @inlinable
    public static func distanceSquared(_ a: P2, _ b: P2) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    @inlinable
    public static func distanceSquared(from point: P2, to segment: Segment) -> Double {
        let delta = segment.delta
        let lengthSquared = delta.lengthSquared
        if lengthSquared <= Tolerance.geometric {
            return distanceSquared(point, segment.a)
        }
        var t = (point - segment.a).dot(delta) / lengthSquared
        if t < 0 {
            t = 0
        } else if t > 1 {
            t = 1
        }
        let projection = P2(x: segment.a.x + delta.x * t, y: segment.a.y + delta.y * t)
        return distanceSquared(point, projection)
    }

    @inlinable
    public static func distanceSquared(from point: P2, to rect: Rect) -> Double {
        let dx =
            point.x < rect.minX
            ? rect.minX - point.x
            : (point.x > rect.maxX ? point.x - rect.maxX : 0)
        let dy =
            point.y < rect.minY
            ? rect.minY - point.y
            : (point.y > rect.maxY ? point.y - rect.maxY : 0)
        return dx * dx + dy * dy
    }

    @inlinable
    public static func overlapArea(_ a: Rect, _ b: Rect) -> Double {
        let width = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        guard width > 0 else { return 0 }
        let height = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        guard height > 0 else { return 0 }
        return width * height
    }

    @inlinable
    public static func intersectionOverUnion(_ a: Rect, _ b: Rect) -> Double {
        let intersection = overlapArea(a, b)
        let union = a.area + b.area - intersection
        return union > 0 ? intersection / union : 0
    }

    @inlinable
    public static func overlaps(
        _ a: Rect,
        _ b: Rect,
        tolerance: Double = Tolerance.overlapEpsilon
    ) -> Bool {
        overlapArea(a, b) > tolerance
    }

    @inlinable
    public static func gapSquared(_ a: Rect, _ b: Rect) -> Double {
        let dx =
            b.minX > a.maxX
            ? b.minX - a.maxX
            : (a.minX > b.maxX ? a.minX - b.maxX : 0)
        let dy =
            b.minY > a.maxY
            ? b.minY - a.maxY
            : (a.minY > b.maxY ? a.minY - b.maxY : 0)
        return dx * dx + dy * dy
    }

    @inlinable
    public static func orientation(
        _ a: P2,
        _ b: P2,
        _ c: P2,
        tolerance: Double = Tolerance.geometric
    ) -> Int {
        let turn = (b - a).cross(c - a)
        if turn > tolerance { return 1 }
        if turn < -tolerance { return -1 }
        return 0
    }

    @inlinable
    static func isWithinBounds(_ point: P2, _ a: P2, _ b: P2, tolerance: Double) -> Bool {
        point.x >= min(a.x, b.x) - tolerance && point.x <= max(a.x, b.x) + tolerance
            && point.y >= min(a.y, b.y) - tolerance && point.y <= max(a.y, b.y) + tolerance
    }

    public static func segmentsIntersect(
        _ first: Segment,
        _ second: Segment,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        let o1 = orientation(first.a, first.b, second.a, tolerance: tolerance)
        let o2 = orientation(first.a, first.b, second.b, tolerance: tolerance)
        let o3 = orientation(second.a, second.b, first.a, tolerance: tolerance)
        let o4 = orientation(second.a, second.b, first.b, tolerance: tolerance)

        if o1 != o2 && o3 != o4 { return true }

        if o1 == 0 && isWithinBounds(second.a, first.a, first.b, tolerance: tolerance) { return true }
        if o2 == 0 && isWithinBounds(second.b, first.a, first.b, tolerance: tolerance) { return true }
        if o3 == 0 && isWithinBounds(first.a, second.a, second.b, tolerance: tolerance) { return true }
        if o4 == 0 && isWithinBounds(first.b, second.a, second.b, tolerance: tolerance) { return true }

        return false
    }

    public static func segmentsProperlyIntersect(
        _ first: Segment,
        _ second: Segment,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        let o1 = orientation(first.a, first.b, second.a, tolerance: tolerance)
        let o2 = orientation(first.a, first.b, second.b, tolerance: tolerance)
        let o3 = orientation(second.a, second.b, first.a, tolerance: tolerance)
        let o4 = orientation(second.a, second.b, first.b, tolerance: tolerance)
        return o1 != o2 && o3 != o4 && o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0
    }

    public static func segmentIntersectsInterior(
        _ segment: Segment,
        of rect: Rect,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        let thinnest = tolerance * Sides.opposite
        guard rect.width > thinnest, rect.height > thinnest else { return false }

        let delta = segment.delta
        var enter = 0.0
        var exit = 1.0

        func clip(_ denominator: Double, _ numerator: Double) -> Bool {
            if denominator > -tolerance && denominator < tolerance {
                return numerator >= 0
            }
            let t = numerator / denominator
            if denominator < 0 {
                if t > exit { return false }
                if t > enter { enter = t }
            } else {
                if t < enter { return false }
                if t < exit { exit = t }
            }
            return true
        }

        guard clip(-delta.x, segment.a.x - rect.minX) else { return false }
        guard clip(delta.x, rect.maxX - segment.a.x) else { return false }
        guard clip(-delta.y, segment.a.y - rect.minY) else { return false }
        guard clip(delta.y, rect.maxY - segment.a.y) else { return false }
        guard exit > enter + tolerance else { return false }

        let middle = half(enter + exit)
        let midpoint = P2(
            x: segment.a.x + delta.x * middle,
            y: segment.a.y + delta.y * middle
        )
        return midpoint.x > rect.minX + tolerance && midpoint.x < rect.maxX - tolerance
            && midpoint.y > rect.minY + tolerance && midpoint.y < rect.maxY - tolerance
    }

    public static func polylineIntersectsInterior(
        _ polyline: Polyline,
        of rect: Rect,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        for segment in polyline.segments
        where segmentIntersectsInterior(segment, of: rect, tolerance: tolerance) {
            return true
        }
        return false
    }

    public static func segmentsOverlapCollinearly(
        _ first: Segment,
        _ second: Segment,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        guard orientation(first.a, first.b, second.a, tolerance: tolerance) == 0,
            orientation(first.a, first.b, second.b, tolerance: tolerance) == 0
        else { return false }

        let direction = first.delta
        let lengthSquared = direction.lengthSquared
        guard lengthSquared > tolerance else { return false }

        func projection(_ point: P2) -> Double {
            (point - first.a).dot(direction) / lengthSquared
        }
        let ownLow = 0.0
        let ownHigh = 1.0
        let otherLow = min(projection(second.a), projection(second.b))
        let otherHigh = max(projection(second.a), projection(second.b))

        let low = max(ownLow, otherLow)
        let high = min(ownHigh, otherHigh)
        return high - low > tolerance
    }

    public static func polylinesConflict(
        _ first: Polyline,
        _ second: Polyline,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        if polylinesProperlyIntersect(first, second, tolerance: tolerance) { return true }
        let secondSegments = second.segments
        for a in first.segments {
            for b in secondSegments
            where segmentsOverlapCollinearly(a, b, tolerance: tolerance) {
                return true
            }
        }
        return false
    }

    public static func polylinesProperlyIntersect(
        _ first: Polyline,
        _ second: Polyline,
        tolerance: Double = Tolerance.geometric
    ) -> Bool {
        let secondSegments = second.segments
        for a in first.segments {
            for b in secondSegments
            where segmentsProperlyIntersect(a, b, tolerance: tolerance) {
                return true
            }
        }
        return false
    }
}
