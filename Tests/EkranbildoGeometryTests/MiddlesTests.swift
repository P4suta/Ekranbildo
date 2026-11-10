@testable import EkranbildoGeometry
import Testing

@Suite("Middles, radii and the room around them")
struct MiddlesTests {

    private let rect = Rect(x: 10, y: 20, width: 100, height: 40)

    @Test("A rectangle built around a point is centred on it")
    func centredOn() {
        let built = Rect(centredOn: P2(x: 50, y: 60), size: Size(width: 20, height: 10))
        #expect(built.center == P2(x: 50, y: 60))
        #expect(built.size == Size(width: 20, height: 10))
        #expect(built.minX == 40)
        #expect(built.minY == 55)
    }

    @Test("A rectangle built around its own middle is itself")
    func roundTrip() {
        #expect(Rect(centredOn: rect.center, size: rect.size) == rect)
    }

    @Test("The radius is half the shorter side")
    func radius() {
        #expect(rect.radius == 20)
        #expect(Rect(x: 0, y: 0, width: 30, height: 90).radius == 15)
    }

    @Test("A rectangle of no size has no radius")
    func noRadius() {
        #expect(Rect.zero.radius == 0)
    }

    @Test("Centring says where the shorter one starts")
    func centring() {
        #expect(Geo.centring(20, in: 100) == 40)
        #expect(Geo.centring(100, in: 100) == 0)
        #expect(Geo.centring(120, in: 100) == -10)
    }

    @Test("Half of something is half of it")
    func half() {
        #expect(Geo.half(10.0) == 5)
        #expect(Geo.half(-3.0) == -1.5)
        #expect(Geo.half(0.0) == 0)
    }

    @Test("The handle that turns a corner into a quarter circle is one number")
    func circleHandle() {
        #expect(Geo.circleHandle > 0.5)
        #expect(Geo.circleHandle < 0.6)
        #expect(Geo.circleHandle == 4.0 / 3.0 * (2.0.squareRoot() - 1))
    }
}

@Suite("Half of a count")
struct HalfCountTests {

    @Test("The middle of an odd count is the index of its middle cell")
    func oddCounts() {
        #expect(Geo.middleIndex(of: 9) == 4)
        #expect(Geo.middleIndex(of: 1) == 0)
        #expect(Geo.middleIndex(of: 15) == 7)
    }

    @Test("Halving a number and finding a middle cell are different questions")
    func notTheSameAsHalving() {
        #expect(Geo.middleIndex(of: 8) == 4)
        #expect(Geo.half(-3.0) == -1.5)
    }
}
