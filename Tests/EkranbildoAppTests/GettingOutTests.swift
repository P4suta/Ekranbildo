import EkranbildoApp
import EkranbildoContracts
import EkranbildoLibrary
import Testing

@Suite("Getting out of a capture")
struct GettingOutTests {

    private static func app() -> AppState {
        AppState(library: Library(), permission: .granted)
    }

    @Test("Asking to capture while choosing puts the overlay away")
    func theShortcutCancels() {
        let choosing = Self.app().handle(.capture)
        #expect(choosing.effects == [.freezeScreens])

        let again = choosing.state.handle(.capture)
        #expect(again.effects == [.dismissOverlay])
        #expect(again.state.screen == .idle)
    }

    @Test("Asking a third time starts a new capture")
    func andThenStartsAgain() {
        var state = Self.app().handle(.capture).state
        state = state.handle(.capture).state
        #expect(state.handle(.capture).effects == [.freezeScreens])
    }

    @Test("It never puts up two overlays")
    func neverTwo() {
        var state = Self.app()
        for _ in 0..<6 {
            let outcome = state.handle(.capture)
            state = outcome.state
            #expect(outcome.effects.count == 1)
        }
    }

    @Test("Escaping the overlay still puts it away")
    func escapeStillWorks() {
        let state = Self.app().handle(.capture).state
        #expect(state.handle(.dismiss).effects == [.dismissOverlay])
    }
}
