import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("Icons")
struct IconTests {

    private static let box = SceneRect(x: 20, y: 30, width: 40, height: 40)

    @Test("Every glyph stays inside the box it was given", arguments: Icon.allCases)
    func insideTheBox(icon: Icon) throws {
        let bounds = try #require(icon.path(in: Self.box).bounds)
        #expect(bounds.minX >= Self.box.minX - Tolerances.edge)
        #expect(bounds.minY >= Self.box.minY - Tolerances.edge)
        #expect(bounds.maxX <= Self.box.maxX + Tolerances.edge)
        #expect(bounds.maxY <= Self.box.maxY + Tolerances.edge)
    }

    @Test("Every glyph fills most of the box it was given", arguments: Icon.allCases)
    func fillsTheBox(icon: Icon) throws {
        let bounds = try #require(icon.path(in: Self.box).bounds)
        #expect(bounds.raw.width >= Self.box.raw.width * Tolerances.fill)
        #expect(bounds.raw.height >= Self.box.raw.height * Tolerances.fill)
    }

    @Test("Every glyph is closed", arguments: Icon.allCases)
    func closed(icon: Icon) {
        let elements = icon.path(in: Self.box).elements
        #expect(elements.last == .close, "\(icon) is left open")
    }

    @Test("A glyph scales rather than changing shape", arguments: Icon.allCases)
    func scales(icon: Icon) throws {
        let small = try #require(icon.path(in: SceneRect(x: 0, y: 0, width: 20, height: 20)).bounds)
        let large = try #require(icon.path(in: SceneRect(x: 0, y: 0, width: 60, height: 60)).bounds)

        let smallRatio = small.raw.width / small.raw.height
        let largeRatio = large.raw.width / large.raw.height
        #expect(approximatelyEqual(smallRatio, largeRatio, tolerance: 1e-9))
    }

    @Test("A glyph moves with the box it is drawn in", arguments: Icon.allCases)
    func moves(icon: Icon) throws {
        let here = try #require(icon.path(in: SceneRect(x: 0, y: 0, width: 40, height: 40)).bounds)
        let there = try #require(
            icon.path(in: SceneRect(x: 100, y: 50, width: 40, height: 40)).bounds)
        #expect(approximatelyEqual(there.minX - here.minX, 100, tolerance: 1e-9))
        #expect(approximatelyEqual(there.minY - here.minY, 50, tolerance: 1e-9))
    }

    @Test("A box of no size gives an empty glyph rather than trapping", arguments: Icon.allCases)
    func emptyBox(icon: Icon) {
        let path = icon.path(in: SceneRect(x: 10, y: 10, width: 0, height: 0))
        #expect(path.bounds == nil || path.bounds?.raw.width == 0)
    }

    @Test("Drawing a glyph is reproducible", arguments: Icon.allCases)
    func reproducible(icon: Icon) {
        #expect(isReproducible { icon.path(in: Self.box) })
    }

    @Test("No two glyphs are the same shape")
    func distinct() {
        let shapes = Icon.allCases.map { $0.path(in: Self.box) }
        #expect(Set(shapes).count == shapes.count)
    }

    @Test("A glyph's hot spot is inside the square it is drawn on", arguments: Icon.allCases)
    func hotSpotIsInsideTheGlyph(icon: Icon) {
        #expect(icon.hotSpot.x >= 0 && icon.hotSpot.x <= 1)
        #expect(icon.hotSpot.y >= 0 && icon.hotSpot.y <= 1)
    }

    @Test("The pointer's hot spot is the tip it is drawn with")
    func pointerPointsFromItsTip() throws {
        let box = SceneRect(x: 0, y: 0, width: 100, height: 100)
        guard case .move(let tip) = try #require(Icon.pointer.path(in: box).elements.first) else {
            Issue.record("expected the pointer's outline to begin somewhere")
            return
        }
        #expect(approximatelyEqual(tip.x, Icon.pointer.hotSpot.x * 100, tolerance: 1e-9))
        #expect(approximatelyEqual(tip.y, Icon.pointer.hotSpot.y * 100, tolerance: 1e-9))
    }

    @Test("A glyph asked to point at somewhere puts its hot spot there", arguments: Icon.allCases)
    func pointsWhereAsked(icon: Icon) {
        let at = ScenePoint(x: 137, y: 42)
        let box = icon.box(size: 24, pointingAt: at)

        #expect(
            approximatelyEqual(
                box.minX + icon.hotSpot.x * box.raw.width, at.x, tolerance: 1e-9))
        #expect(
            approximatelyEqual(
                box.minY + icon.hotSpot.y * box.raw.height, at.y, tolerance: 1e-9))
    }

    @Test("A glyph asked to point at somewhere is drawn at the size asked for")
    func pointsAtTheSizeAsked() {
        let box = Icon.pointer.box(size: 24, pointingAt: ScenePoint(x: 0, y: 0))
        #expect(box.raw.width == 24)
        #expect(box.raw.height == 24)
    }

    private enum Tolerances {
        static let edge: Double = 1e-9
        static let fill: Double = 0.5
    }
}
