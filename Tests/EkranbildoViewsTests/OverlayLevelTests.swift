import AppKit
@testable import EkranbildoViews
import Testing

@Suite("How high the overlay sits")
@MainActor
struct OverlayLevelTests {

    @Test("It is above the menu bar, the Dock, and anything an application puts up")
    func aboveTheOrdinary() {
        #expect(OverlayWindow.level.rawValue > Int(CGWindowLevelForKey(.popUpMenuWindow)))
        #expect(OverlayWindow.level.rawValue > Int(CGWindowLevelForKey(.mainMenuWindow)))
        #expect(OverlayWindow.level.rawValue > Int(CGWindowLevelForKey(.dockWindow)))
        #expect(OverlayWindow.level.rawValue > Int(CGWindowLevelForKey(.floatingWindow)))
    }

    @Test("It is below the level the system shields the machine with")
    func belowTheShield() {
        #expect(OverlayWindow.level.rawValue < Int(CGShieldingWindowLevel()))
        #expect(OverlayWindow.level.rawValue < Int(CGWindowLevelForKey(.maximumWindow)))
    }

    @Test("It does not sit above the screen saver or the login window")
    func belowTheSystemsOwn() {
        #expect(OverlayWindow.level.rawValue <= Int(CGWindowLevelForKey(.screenSaverWindow)))
    }
}
