import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoOverlay
import EkranbildoTestKit
import Testing

@Suite("Magnifier")
struct MagnifierTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 320, height: 220),
        backingScale: 1
    )

    private func frozen() -> FrozenScreen {
        FrozenScreen(
            display: Self.display,
            image: SceneLibrary.applicationWindow.image,
            windows: WindowStack(windows: [])
        )
    }

    @Test("The magnified square is centred on the pointer")
    func centred() {
        let point = ScreenPoint(x: 100, y: 80)
        let looked = Magnifier(across: 15).look(at: point, in: frozen())
        #expect(looked.area.minX == point.x - 7)
        #expect(looked.area.minY == point.y - 7)
        #expect(looked.area.raw.contains(point.raw))
    }

    @Test("It shows as many pixels across as it was asked for")
    func size() {
        let looked = Magnifier(across: 9).look(at: ScreenPoint(x: 100, y: 80), in: frozen())
        #expect(looked.pixels.count == 9 * 9)
        #expect(looked.across == 9)
    }

    @Test("The middle pixel is the one under the pointer")
    func middleIsUnderThePointer() {
        let screen = SceneLibrary.applicationWindow
        let looked = Magnifier(across: 5).look(at: ScreenPoint(x: 20, y: 12), in: frozen())
        #expect(looked.centre == screen.image[x: 20, y: 12])
    }

    @Test("Looking at the edge shows what is there and nothing beyond it")
    func atTheEdge() {
        let looked = Magnifier(across: 7).look(at: ScreenPoint(x: 0, y: 0), in: frozen())
        #expect(looked.pixels.count == 7 * 7)
        #expect(looked.pixels[0].alpha == 0)
    }

    @Test("Looking outside the picture altogether is empty rather than a failure")
    func outsideEntirely() {
        let looked = Magnifier().look(at: ScreenPoint(x: 5000, y: 5000), in: frozen())
        #expect(looked.pixels.allSatisfy { $0.alpha == 0 })
    }

    @Test("The square always has a middle")
    func alwaysOdd() {
        #expect(Magnifier(across: 8).across % 2 == 1)
        #expect(Magnifier(across: 0).across % 2 == 1)
        #expect(Magnifier(across: -3).across % 2 == 1)
    }

    @Test("The colour under the pointer reads as a hex value")
    func hexReadout() {
        let pixel = ImageBuffer.Pixel(red: 0x2E, green: 0x86, blue: 0xDE, alpha: 255)
        #expect(Magnifier.hex(of: pixel) == "#2E86DE")
    }

    @Test("Black and white read as themselves")
    func extremes() {
        #expect(Magnifier.hex(of: .opaque(red: 0, green: 0, blue: 0)) == "#000000")
        #expect(Magnifier.hex(of: .opaque(red: 255, green: 255, blue: 255)) == "#FFFFFF")
    }

    @Test("Every channel is two digits")
    func padsDigits() {
        #expect(Magnifier.hex(of: .opaque(red: 1, green: 2, blue: 3)) == "#010203")
    }

    @Test("Looking is reproducible")
    func reproducible() {
        let screen = frozen()
        #expect(isReproducible { Magnifier().look(at: ScreenPoint(x: 40, y: 30), in: screen) })
    }
}
