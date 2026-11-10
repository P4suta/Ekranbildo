import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoOverlay
import Testing

@Suite("Which screen the keyboard belongs to")
struct WhichScreenTests {

    private static let laptop = Rect(x: 0, y: 0, width: 1728, height: 1117)
    private static let monitor = Rect(x: -77, y: -1080, width: 1920, height: 1080)

    private func choose(_ pointer: P2, among screens: [Rect]) -> Int? {
        Overlay.screenUnder(ScreenPoint(pointer), among: screens.map { ScreenRect($0) })
    }

    @Test("The pointer's own screen gets it")
    func pointerOnTheLaptop() {
        #expect(choose(P2(x: 800, y: 500), among: [Self.laptop, Self.monitor]) == 0)
    }

    @Test("A pointer on the other screen gets that one, whatever order they came in")
    func pointerOnTheMonitor() {
        #expect(choose(P2(x: 800, y: -500), among: [Self.laptop, Self.monitor]) == 1)
        #expect(choose(P2(x: 800, y: -500), among: [Self.monitor, Self.laptop]) == 0)
    }

    @Test("A pointer at a negative coordinate is still on a screen")
    func negativeCoordinates() {
        #expect(choose(P2(x: -50, y: -1000), among: [Self.laptop, Self.monitor]) == 1)
    }

    @Test("A pointer on no screen at all falls to the first")
    func pointerNowhere() {
        #expect(choose(P2(x: 9000, y: 9000), among: [Self.laptop, Self.monitor]) == 0)
    }

    @Test("With no screens there is nothing to choose")
    func noScreens() {
        #expect(choose(P2(x: 0, y: 0), among: []) == nil)
    }

    @Test("With one screen it is that one wherever the pointer is")
    func oneScreen() {
        #expect(choose(P2(x: 9000, y: 9000), among: [Self.laptop]) == 0)
    }

    @Test("A pointer on a shared edge goes to one screen, always the same one")
    func onTheEdge() {
        let above = Rect(x: 0, y: -1080, width: 1728, height: 1080)
        let chosen = choose(P2(x: 800, y: 0), among: [Self.laptop, above])
        #expect(chosen == choose(P2(x: 800, y: 0), among: [Self.laptop, above]))
        #expect(chosen != nil)
    }
}
