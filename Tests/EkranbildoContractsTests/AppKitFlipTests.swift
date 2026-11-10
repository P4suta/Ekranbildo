@testable import EkranbildoContracts
import EkranbildoGeometry
import Testing

@Suite("AppKit point flip")
struct AppKitPointFlipTests {

    @Test("A point at the AppKit origin maps to the bottom of the primary display")
    func originMapsToBottom() {
        let flipped = AppKitCoordinates.screenPoint(
            fromAppKitPoint: P2(x: 7, y: 0), primaryDisplayHeight: 982)
        #expect(flipped == ScreenPoint(x: 7, y: 982))
    }

    @Test("A point at the top of the primary display maps to zero")
    func topMapsToZero() {
        let flipped = AppKitCoordinates.screenPoint(
            fromAppKitPoint: P2(x: 0, y: 982),
            primaryDisplayHeight: 982
        )
        #expect(flipped == ScreenPoint(x: 0, y: 0))
    }

    @Test("The X coordinate is never touched")
    func horizontalIsUnchanged() {
        var generator = SplitMix64(seed: 53)
        for _ in 0..<200 {
            let x = Double(generator.next() % 8_000) / 2 - 2_000
            let flipped = AppKitCoordinates.screenPoint(
                fromAppKitPoint: P2(x: x, y: 123),
                primaryDisplayHeight: 900
            )
            #expect(flipped.x == x)
        }
    }
}
