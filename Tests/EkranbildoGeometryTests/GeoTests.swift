@testable import EkranbildoGeometry
import Testing

@Suite("Geo distances")
struct GeoDistanceTests {

    @Test("Distance between points is squared Euclidean distance")
    func pointToPoint() {
        #expect(Geo.distanceSquared(P2(x: 0, y: 0), P2(x: 3, y: 4)) == 25)
        #expect(Geo.distanceSquared(P2(x: 1, y: 1), P2(x: 1, y: 1)) == 0)
    }

    @Test("Distance to a segment uses the perpendicular foot when it falls inside")
    func pointToSegmentPerpendicular() {
        let segment = Segment(a: P2(x: 0, y: 0), b: P2(x: 10, y: 0))
        #expect(Geo.distanceSquared(from: P2(x: 5, y: 3), to: segment) == 9)
    }

    @Test("Distance to a segment clamps to the endpoints")
    func pointToSegmentClamped() {
        let segment = Segment(a: P2(x: 0, y: 0), b: P2(x: 10, y: 0))
        #expect(Geo.distanceSquared(from: P2(x: 15, y: 0), to: segment) == 25)
        #expect(Geo.distanceSquared(from: P2(x: -3, y: 4), to: segment) == 25)
    }

    @Test("A degenerate segment behaves as a point")
    func degenerateSegment() {
        let point = Segment(a: P2(x: 2, y: 2), b: P2(x: 2, y: 2))
        #expect(Geo.distanceSquared(from: P2(x: 5, y: 6), to: point) == 25)
    }

    @Test("Distance to a rectangle is zero inside and positive outside")
    func pointToRect() {
        let rect = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(Geo.distanceSquared(from: P2(x: 5, y: 5), to: rect) == 0)
        #expect(Geo.distanceSquared(from: P2(x: 0, y: 0), to: rect) == 0)
        #expect(Geo.distanceSquared(from: P2(x: 13, y: 5), to: rect) == 9)
        #expect(Geo.distanceSquared(from: P2(x: 13, y: 14), to: rect) == 25)
    }
}

@Suite("Geo rectangles")
struct GeoRectangleTests {

    @Test("Overlap area is zero for disjoint and for merely touching rectangles")
    func noOverlap() {
        let left = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(Geo.overlapArea(left, Rect(x: 20, y: 0, width: 10, height: 10)) == 0)
        #expect(Geo.overlapArea(left, Rect(x: 10, y: 0, width: 10, height: 10)) == 0)
        #expect(Geo.overlapArea(left, Rect(x: 10, y: 10, width: 10, height: 10)) == 0)
    }

    @Test("Overlap area is computed for partial and full containment")
    func overlapArea() {
        let base = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(Geo.overlapArea(base, Rect(x: 5, y: 5, width: 10, height: 10)) == 25)
        #expect(Geo.overlapArea(base, Rect(x: 2, y: 2, width: 3, height: 4)) == 12)
        #expect(Geo.overlapArea(base, base) == 100)
    }

    @Test("Overlap area is symmetric")
    func overlapIsSymmetric() {
        let first = Rect(x: 1, y: 2, width: 7, height: 3)
        let second = Rect(x: 4, y: 0, width: 9, height: 6)
        #expect(Geo.overlapArea(first, second) == Geo.overlapArea(second, first))
    }

    @Test("Touching rectangles do not count as overlapping")
    func overlapsPredicate() {
        let left = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(!Geo.overlaps(left, Rect(x: 10, y: 0, width: 10, height: 10)))
        #expect(Geo.overlaps(left, Rect(x: 9, y: 0, width: 10, height: 10)))
    }

    @Test("Gap is zero when rectangles overlap or touch, and positive when separated")
    func gapSquared() {
        let base = Rect(x: 0, y: 0, width: 10, height: 10)
        #expect(Geo.gapSquared(base, Rect(x: 5, y: 5, width: 10, height: 10)) == 0)
        #expect(Geo.gapSquared(base, Rect(x: 10, y: 0, width: 5, height: 5)) == 0)
        #expect(Geo.gapSquared(base, Rect(x: 13, y: 0, width: 5, height: 5)) == 9)
        #expect(Geo.gapSquared(base, Rect(x: 13, y: 14, width: 5, height: 5)) == 25)
    }

    @Test("Gap is symmetric")
    func gapIsSymmetric() {
        let first = Rect(x: 0, y: 0, width: 4, height: 4)
        let second = Rect(x: 9, y: 12, width: 3, height: 3)
        #expect(Geo.gapSquared(first, second) == Geo.gapSquared(second, first))
    }
}

@Suite("Geo orientation")
struct GeoOrientationTests {

    @Test("Orientation reports a consistent sign for each turn direction")
    func orientationSigns() {
        let origin = P2(x: 0, y: 0)
        let right = P2(x: 1, y: 0)
        #expect(Geo.orientation(origin, right, P2(x: 1, y: 1)) == 1)
        #expect(Geo.orientation(origin, right, P2(x: 1, y: -1)) == -1)
        #expect(Geo.orientation(origin, right, P2(x: 2, y: 0)) == 0)
    }

    @Test("Swapping the first two points reverses the orientation")
    func orientationIsAntisymmetric() {
        let a = P2(x: 0, y: 0)
        let b = P2(x: 4, y: 1)
        let c = P2(x: 2, y: 5)
        #expect(Geo.orientation(a, b, c) == -Geo.orientation(b, a, c))
    }

    @Test("Nearly collinear points within tolerance report collinear")
    func orientationTolerance() {
        let a = P2(x: 0, y: 0)
        let b = P2(x: 1_000, y: 0)
        #expect(Geo.orientation(a, b, P2(x: 500, y: 1e-15)) == 0)
    }
}

@Suite("Geo segment intersection")
struct GeoSegmentIntersectionTests {

    @Test("Crossing segments intersect")
    func crossing() {
        let horizontal = Segment(a: P2(x: 0, y: 5), b: P2(x: 10, y: 5))
        let vertical = Segment(a: P2(x: 5, y: 0), b: P2(x: 5, y: 10))
        #expect(Geo.segmentsIntersect(horizontal, vertical))
        #expect(Geo.segmentsProperlyIntersect(horizontal, vertical))
    }

    @Test("Disjoint segments do not intersect")
    func disjoint() {
        let first = Segment(a: P2(x: 0, y: 0), b: P2(x: 1, y: 1))
        let second = Segment(a: P2(x: 5, y: 5), b: P2(x: 6, y: 6))
        #expect(!Geo.segmentsIntersect(first, second))
        #expect(!Geo.segmentsProperlyIntersect(first, second))
    }

    @Test("Parallel segments never intersect")
    func parallel() {
        let first = Segment(a: P2(x: 0, y: 0), b: P2(x: 10, y: 0))
        let second = Segment(a: P2(x: 0, y: 3), b: P2(x: 10, y: 3))
        #expect(!Geo.segmentsIntersect(first, second))
    }

    @Test("Sharing only an endpoint is contact but not a proper crossing")
    func sharedEndpoint() {
        let shared = P2(x: 5, y: 5)
        let first = Segment(a: shared, b: P2(x: 10, y: 0))
        let second = Segment(a: shared, b: P2(x: 10, y: 10))
        #expect(Geo.segmentsIntersect(first, second))
        #expect(!Geo.segmentsProperlyIntersect(first, second))
    }

    @Test("A T-junction touches but does not properly cross")
    func touchingMidpoint() {
        let spine = Segment(a: P2(x: 0, y: 0), b: P2(x: 10, y: 0))
        let branch = Segment(a: P2(x: 5, y: 0), b: P2(x: 5, y: 8))
        #expect(Geo.segmentsIntersect(spine, branch))
        #expect(!Geo.segmentsProperlyIntersect(spine, branch))
    }

    @Test("Overlapping collinear segments touch but do not properly cross")
    func collinearOverlap() {
        let first = Segment(a: P2(x: 0, y: 0), b: P2(x: 10, y: 0))
        let second = Segment(a: P2(x: 5, y: 0), b: P2(x: 15, y: 0))
        #expect(Geo.segmentsIntersect(first, second))
        #expect(!Geo.segmentsProperlyIntersect(first, second))
    }

    @Test("Collinear but separated segments do not intersect")
    func collinearDisjoint() {
        let first = Segment(a: P2(x: 0, y: 0), b: P2(x: 5, y: 0))
        let second = Segment(a: P2(x: 8, y: 0), b: P2(x: 12, y: 0))
        #expect(!Geo.segmentsIntersect(first, second))
    }

    @Test("Intersection is symmetric in its arguments")
    func intersectionIsSymmetric() {
        var generator = SplitMix64(seed: 99)
        func coordinate() -> Double { Double(generator.next() % 200) / 10.0 }
        for _ in 0..<300 {
            let first = Segment(
                a: P2(x: coordinate(), y: coordinate()),
                b: P2(x: coordinate(), y: coordinate())
            )
            let second = Segment(
                a: P2(x: coordinate(), y: coordinate()),
                b: P2(x: coordinate(), y: coordinate())
            )
            #expect(Geo.segmentsIntersect(first, second) == Geo.segmentsIntersect(second, first))
            #expect(
                Geo.segmentsProperlyIntersect(first, second)
                    == Geo.segmentsProperlyIntersect(second, first)
            )
        }
    }

    @Test("A proper crossing always implies a plain intersection")
    func properCrossingImpliesIntersection() {
        var generator = SplitMix64(seed: 2024)
        func coordinate() -> Double { Double(generator.next() % 100) / 5.0 }
        for _ in 0..<300 {
            let first = Segment(
                a: P2(x: coordinate(), y: coordinate()),
                b: P2(x: coordinate(), y: coordinate())
            )
            let second = Segment(
                a: P2(x: coordinate(), y: coordinate()),
                b: P2(x: coordinate(), y: coordinate())
            )
            if Geo.segmentsProperlyIntersect(first, second) {
                #expect(Geo.segmentsIntersect(first, second))
            }
        }
    }
}

@Suite("Geo segment against rectangle interior")
struct GeoInteriorTests {
    private let box = Rect(x: 0, y: 0, width: 10, height: 10)

    @Test("A segment passing clean through enters the interior")
    func passesThrough() {
        let crossing = Segment(a: P2(x: -5, y: 5), b: P2(x: 15, y: 5))
        #expect(Geo.segmentIntersectsInterior(crossing, of: box))
    }

    @Test("A segment entirely inside is in the interior")
    func fullyInside() {
        let inside = Segment(a: P2(x: 2, y: 2), b: P2(x: 8, y: 8))
        #expect(Geo.segmentIntersectsInterior(inside, of: box))
    }

    @Test("A segment entirely outside is not in the interior")
    func fullyOutside() {
        let outside = Segment(a: P2(x: 20, y: 20), b: P2(x: 30, y: 30))
        #expect(!Geo.segmentIntersectsInterior(outside, of: box))
    }

    @Test("A segment running along an edge does not enter the interior")
    func alongAnEdge() {
        let alongTop = Segment(a: P2(x: -5, y: 0), b: P2(x: 15, y: 0))
        let alongLeft = Segment(a: P2(x: 0, y: -5), b: P2(x: 0, y: 15))
        let alongBottom = Segment(a: P2(x: -5, y: 10), b: P2(x: 15, y: 10))
        #expect(!Geo.segmentIntersectsInterior(alongTop, of: box))
        #expect(!Geo.segmentIntersectsInterior(alongLeft, of: box))
        #expect(!Geo.segmentIntersectsInterior(alongBottom, of: box))
    }

    @Test("A segment grazing a corner does not enter the interior")
    func grazingACorner() {
        let graze = Segment(a: P2(x: -5, y: 5), b: P2(x: 5, y: -5))
        #expect(!Geo.segmentIntersectsInterior(graze, of: box))
    }

    @Test("A segment ending just inside enters the interior")
    func endingInside() {
        let poking = Segment(a: P2(x: -5, y: 5), b: P2(x: 1, y: 5))
        #expect(Geo.segmentIntersectsInterior(poking, of: box))
    }

    @Test("A segment that only touches the boundary at its endpoint stays outside")
    func touchingBoundaryOnly() {
        let touching = Segment(a: P2(x: -5, y: 5), b: P2(x: 0, y: 5))
        #expect(!Geo.segmentIntersectsInterior(touching, of: box))
    }

    @Test("A degenerate rectangle has no interior")
    func degenerateRectangle() {
        let line = Rect(x: 0, y: 0, width: 10, height: 0)
        let crossing = Segment(a: P2(x: -5, y: 0), b: P2(x: 15, y: 0))
        #expect(!Geo.segmentIntersectsInterior(crossing, of: line))
    }

    @Test("Polyline interior test reports any segment entering the rectangle")
    func polylineInterior() {
        let missing = Polyline(points: [P2(x: -5, y: -5), P2(x: -5, y: 20), P2(x: 20, y: 20)])
        let hitting = Polyline(points: [P2(x: -5, y: 5), P2(x: 5, y: 5), P2(x: 5, y: 20)])
        #expect(!Geo.polylineIntersectsInterior(missing, of: box))
        #expect(Geo.polylineIntersectsInterior(hitting, of: box))
    }

    @Test("A polyline with fewer than two points has no segments")
    func degeneratePolyline() {
        #expect(!Geo.polylineIntersectsInterior(Polyline(points: []), of: box))
        #expect(!Geo.polylineIntersectsInterior(Polyline(points: [P2(x: 5, y: 5)]), of: box))
    }

    @Test("Two polylines sharing a tail point do not properly cross")
    func polylinesSharingATail() {
        let tail = P2(x: 5, y: 5)
        let first = Polyline(points: [tail, P2(x: 20, y: 0)])
        let second = Polyline(points: [tail, P2(x: 20, y: 10)])
        #expect(!Geo.polylinesProperlyIntersect(first, second))
    }

    @Test("Two polylines that genuinely cross are detected")
    func polylinesCrossing() {
        let first = Polyline(points: [P2(x: 0, y: 0), P2(x: 10, y: 10)])
        let second = Polyline(points: [P2(x: 0, y: 10), P2(x: 10, y: 0)])
        #expect(Geo.polylinesProperlyIntersect(first, second))
    }
}
