@testable import EkranbildoGeometry
import Testing

@Suite("Geo polyline conflicts")
struct GeoConflictTests {

    @Test("Crossing polylines conflict")
    func crossing() {
        let first = Polyline(points: [P2(x: 0, y: 0), P2(x: 10, y: 10)])
        let second = Polyline(points: [P2(x: 0, y: 10), P2(x: 10, y: 0)])
        #expect(Geo.polylinesConflict(first, second))
    }

    @Test("Polylines lying along each other conflict")
    func collinearOverlap() {
        let first = Polyline(points: [P2(x: 0, y: 5), P2(x: 20, y: 5)])
        let second = Polyline(points: [P2(x: 10, y: 5), P2(x: 30, y: 5)])
        #expect(!Geo.polylinesProperlyIntersect(first, second))
        #expect(Geo.polylinesConflict(first, second))
    }

    @Test("One polyline contained within another conflicts")
    func collinearContainment() {
        let long = Polyline(points: [P2(x: 0, y: 5), P2(x: 40, y: 5)])
        let short = Polyline(points: [P2(x: 10, y: 5), P2(x: 20, y: 5)])
        #expect(Geo.polylinesConflict(long, short))
    }

    @Test("Touching end to end does not conflict")
    func endToEnd() {
        let first = Polyline(points: [P2(x: 0, y: 5), P2(x: 10, y: 5)])
        let second = Polyline(points: [P2(x: 10, y: 5), P2(x: 20, y: 5)])
        #expect(!Geo.polylinesConflict(first, second))
    }

    @Test("Parallel but separated polylines do not conflict")
    func parallelSeparated() {
        let first = Polyline(points: [P2(x: 0, y: 5), P2(x: 20, y: 5)])
        let second = Polyline(points: [P2(x: 0, y: 9), P2(x: 20, y: 9)])
        #expect(!Geo.polylinesConflict(first, second))
    }

    @Test("Disjoint polylines do not conflict")
    func disjoint() {
        let first = Polyline(points: [P2(x: 0, y: 0), P2(x: 5, y: 5)])
        let second = Polyline(points: [P2(x: 40, y: 40), P2(x: 50, y: 50)])
        #expect(!Geo.polylinesConflict(first, second))
    }

    @Test("Conflict is symmetric")
    func symmetric() {
        var generator = SplitMix64(seed: 616)
        func coordinate() -> Double { Double(generator.next() % 40) }
        for _ in 0..<300 {
            let first = Polyline(points: [
                P2(x: coordinate(), y: coordinate()), P2(x: coordinate(), y: coordinate()),
            ])
            let second = Polyline(points: [
                P2(x: coordinate(), y: coordinate()), P2(x: coordinate(), y: coordinate()),
            ])
            #expect(Geo.polylinesConflict(first, second) == Geo.polylinesConflict(second, first))
        }
    }

    @Test("A proper crossing always counts as a conflict")
    func crossingImpliesConflict() {
        var generator = SplitMix64(seed: 617)
        func coordinate() -> Double { Double(generator.next() % 40) }
        for _ in 0..<300 {
            let first = Polyline(points: [
                P2(x: coordinate(), y: coordinate()), P2(x: coordinate(), y: coordinate()),
            ])
            let second = Polyline(points: [
                P2(x: coordinate(), y: coordinate()), P2(x: coordinate(), y: coordinate()),
            ])
            if Geo.polylinesProperlyIntersect(first, second) {
                #expect(Geo.polylinesConflict(first, second))
            }
        }
    }
}
