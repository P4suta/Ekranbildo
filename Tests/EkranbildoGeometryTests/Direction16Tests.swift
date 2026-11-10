@testable import EkranbildoGeometry
import Testing

@Suite("Direction16")
struct Direction16Tests {

    @Test("Unit vectors have length one", arguments: Direction16.allCases)
    func unitVectorsAreNormalized(_ direction: Direction16) {
        #expect(approximatelyEqual(direction.unit.lengthSquared, 1.0, tolerance: 1e-12))
    }

    @Test("Adjacent directions are 22.5 degrees apart", arguments: Direction16.allCases)
    func adjacentDirectionsAreSeparatedByOneStep(_ direction: Direction16) {
        let next = Direction16(rawValue: (direction.rawValue + 1) % 16)!
        #expect(
            approximatelyEqual(
                direction.unit.dot(next.unit),
                0.923_879_532_511_286_8,
                tolerance: 1e-12
            )
        )
    }

    @Test("North points up the screen because scene space has Y pointing down")
    func northIsUpInSceneSpace() {
        #expect(Direction16.n.unit == P2(x: 0, y: -1))
        #expect(Direction16.s.unit == P2(x: 0, y: 1))
        #expect(Direction16.e.unit == P2(x: 1, y: 0))
        #expect(Direction16.w.unit == P2(x: -1, y: 0))
    }

    @Test("Opposite negates the unit vector", arguments: Direction16.allCases)
    func oppositeNegatesTheUnitVector(_ direction: Direction16) {
        let flipped = direction.opposite.unit
        #expect(approximatelyEqual(flipped.x, -direction.unit.x, tolerance: 1e-12))
        #expect(approximatelyEqual(flipped.y, -direction.unit.y, tolerance: 1e-12))
    }

    @Test("Horizontal mirroring negates X", arguments: Direction16.allCases)
    func horizontalMirrorNegatesX(_ direction: Direction16) {
        let mirrored = direction.mirroredHorizontally.unit
        #expect(
            approximatelyEqual(mirrored.x, -direction.unit.x, tolerance: 1e-12),
            "\(direction) mirrored horizontally should have x=\(-direction.unit.x)"
        )
        #expect(
            approximatelyEqual(mirrored.y, direction.unit.y, tolerance: 1e-12),
            "\(direction) mirrored horizontally should have y=\(direction.unit.y)"
        )
    }

    @Test("Vertical mirroring negates Y", arguments: Direction16.allCases)
    func verticalMirrorNegatesY(_ direction: Direction16) {
        let mirrored = direction.mirroredVertically.unit
        #expect(
            approximatelyEqual(mirrored.x, direction.unit.x, tolerance: 1e-12),
            "\(direction) mirrored vertically should have x=\(direction.unit.x)"
        )
        #expect(
            approximatelyEqual(mirrored.y, -direction.unit.y, tolerance: 1e-12),
            "\(direction) mirrored vertically should have y=\(-direction.unit.y)"
        )
    }

    @Test("Mirroring is an involution", arguments: Direction16.allCases)
    func mirrorsAreInvolutions(_ direction: Direction16) {
        #expect(direction.mirroredHorizontally.mirroredHorizontally == direction)
        #expect(direction.mirroredVertically.mirroredVertically == direction)
        #expect(direction.opposite.opposite == direction)
    }

    @Test("Mirroring on both axes equals the opposite direction", arguments: Direction16.allCases)
    func bothMirrorsComposeToOpposite(_ direction: Direction16) {
        #expect(direction.mirroredHorizontally.mirroredVertically == direction.opposite)
    }

    @Test("Step distance is the shortest way around the circle")
    func stepDistanceIsCircular() {
        #expect(Direction16.e.stepDistance(to: .e) == 0)
        #expect(Direction16.e.stepDistance(to: .ene) == 1)
        #expect(Direction16.e.stepDistance(to: .ese) == 1)
        #expect(Direction16.e.stepDistance(to: .w) == 8)
        #expect(Direction16.nne.stepDistance(to: .ssw) == 8)
    }

    @Test("Step distance is symmetric", arguments: Direction16.allCases)
    func stepDistanceIsSymmetric(_ direction: Direction16) {
        for other in Direction16.allCases {
            #expect(direction.stepDistance(to: other) == other.stepDistance(to: direction))
        }
    }

    @Test("Only the four cardinal directions are axis aligned")
    func axisAlignedDirections() {
        #expect(Direction16.allCases.filter(\.isAxisAligned) == [.e, .n, .w, .s])
    }

    @Test("allCases iterates in raw-value order so iteration is deterministic")
    func allCasesIsOrdered() {
        #expect(Direction16.allCases.map(\.rawValue) == Array(UInt8(0)...UInt8(15)))
    }
}
