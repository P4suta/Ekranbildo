@testable import EkranbildoGeometry
import Testing

@Suite("The nearest of the sixteen directions")
struct NearestDirectionTests {

    @Test(
        "A point straight along a direction is that direction",
        arguments: Direction16.allCases
    )
    func straightAlong(_ direction: Direction16) {
        let unit = direction.unit
        #expect(Direction16.nearest(to: P2(x: unit.x * 100, y: unit.y * 100)) == direction)
    }

    @Test("Distance does not change which direction it is")
    func distanceDoesNotMatter() {
        for scale in [0.001, 1.0, 1000.0, 1_000_000.0] {
            #expect(Direction16.nearest(to: P2(x: scale, y: 0)) == .e)
            #expect(Direction16.nearest(to: P2(x: -scale, y: -scale)) == .nw)
        }
    }

    @Test("North is upwards on the screen, which is a smaller Y")
    func northIsUp() {
        #expect(Direction16.nearest(to: P2(x: 0, y: -10)) == .n)
        #expect(Direction16.nearest(to: P2(x: 0, y: 10)) == .s)
    }

    @Test("No offset at all is a direction rather than nothing")
    func noOffset() {
        #expect(Direction16.nearest(to: P2(x: 0, y: 0)) == .e)
    }

    @Test("A point exactly between two directions always gives the same one")
    func exactlyBetween() {
        let between = P2(
            x: Direction16.e.unit.x + Direction16.ene.unit.x,
            y: Direction16.e.unit.y + Direction16.ene.unit.y
        )
        let once = Direction16.nearest(to: between)
        #expect(once == Direction16.nearest(to: between))
        #expect(once == .e || once == .ene)
    }

    @Test("Anything not finite is a direction rather than a crash")
    func notFinite() {
        #expect(Direction16.nearest(to: P2(x: .nan, y: .nan)) == .e)
        #expect(Direction16.nearest(to: P2(x: .infinity, y: 0)) == .e)
    }
}
