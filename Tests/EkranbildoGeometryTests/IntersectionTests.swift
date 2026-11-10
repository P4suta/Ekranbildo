@testable import EkranbildoGeometry
import Testing

@Suite("Where two rectangles meet")
struct IntersectionTests {

    private let screen = Rect(x: 0, y: 0, width: 800, height: 600)

    @Test("A rectangle inside another is itself")
    func inside() {
        let small = Rect(x: 100, y: 100, width: 200, height: 200)
        #expect(screen.intersection(small) == small)
        #expect(small.intersection(screen) == small)
    }

    @Test(
        "A rectangle over an edge is the part that is inside",
        arguments: [
            (Rect(x: -50, y: 100, width: 200, height: 100), Rect(x: 0, y: 100, width: 150, height: 100)),
            (Rect(x: 700, y: 100, width: 200, height: 100), Rect(x: 700, y: 100, width: 100, height: 100)),
            (Rect(x: 100, y: -50, width: 100, height: 200), Rect(x: 100, y: 0, width: 100, height: 150)),
            (Rect(x: 100, y: 500, width: 100, height: 200), Rect(x: 100, y: 500, width: 100, height: 100)),
        ]
    )
    func overAnEdge(_ swept: Rect, _ expected: Rect) {
        #expect(screen.intersection(swept) == expected)
    }

    @Test("A rectangle around another is the other")
    func around() {
        #expect(
            screen.intersection(Rect(x: -100, y: -100, width: 2000, height: 2000)) == screen)
    }

    @Test("Rectangles that do not meet meet nowhere")
    func apart() {
        #expect(screen.intersection(Rect(x: 900, y: 0, width: 100, height: 100)) == nil)
        #expect(screen.intersection(Rect(x: 0, y: 700, width: 100, height: 100)) == nil)
    }

    @Test("Rectangles that only touch meet nowhere")
    func touching() {
        #expect(screen.intersection(Rect(x: 800, y: 0, width: 100, height: 100)) == nil)
        #expect(screen.intersection(Rect(x: 0, y: 600, width: 100, height: 100)) == nil)
    }

    @Test("Where two rectangles meet does not depend on which is asked")
    func symmetric() {
        let one = Rect(x: -20, y: 30, width: 500, height: 900)
        #expect(screen.intersection(one) == one.intersection(screen))
    }

    @Test("What comes back is inside both")
    func containedInBoth() throws {
        let other = Rect(x: -20, y: 30, width: 500, height: 900)
        let met = try #require(screen.intersection(other))
        #expect(screen.contains(met))
        #expect(other.contains(met))
    }
}
