import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Capturing a scroll")
struct CapturingAScrollTests {

    private static let region = ScreenRect(x: 100, y: 80, width: 600, height: 400)

    private static func app() -> AppState {
        AppState(library: Library(), permission: .granted)
    }

    private static func choosing() -> AppState {
        app().handle(.captureScrolling).state
    }

    @Test("Asking for one puts the overlay up to choose a region with")
    func startsByChoosing() {
        let outcome = Self.app().handle(.captureScrolling)
        #expect(outcome.effects == [.freezeScreens])
        #expect(outcome.state.screen == .choosingRegion)
    }

    @Test("The region chosen is the one the frames come from")
    func remembersTheRegion() {
        let state = Self.choosing().handle(.choseScrollRegion(Self.region))
        #expect(state.effects == [.dismissOverlay, .followTheScroll(Self.region)])
        #expect(state.state.screen == .scrolling)
    }

    @Test("While scrolling, what has been seen is known")
    func progress() {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.scrolled(seen: 700, advice: .keepGoing)).state
        #expect(state.scroll?.seen == 700)
        #expect(state.scroll?.advice == .keepGoing)
    }

    @Test("Being told to slow down is remembered until it stops being true")
    func advice() {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.scrolled(seen: 700, advice: .slowDown)).state
        #expect(state.scroll?.advice == .slowDown)
        state = state.handle(.scrolled(seen: 900, advice: .keepGoing)).state
        #expect(state.scroll?.advice == .keepGoing)
    }

    @Test("Finishing asks for the frames to be joined")
    func finishing() {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.scrolled(seen: 700, advice: .keepGoing)).state
        let outcome = state.handle(.finishScrolling)
        #expect(outcome.effects == [.joinTheScroll])
        #expect(outcome.state.screen == .idle)
        #expect(outcome.state.scroll == nil)
    }

    @Test("What was joined opens like any other capture")
    func joined() throws {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.finishScrolling).state
        let tall = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 600, height: 2400),
            background: ImageRef(contentHash: "joined", pixelWidth: 600, pixelHeight: 2400),
            annotations: [],
            style: .standard
        )
        let outcome = state.handle(.captured(tall, at: Timestamp.seconds(1)))
        #expect(outcome.effects.contains(.openEditor(DocumentID(1))))
        #expect(try #require(outcome.state.library.newest).canvas.height == 2400)
    }

    @Test("Changing your mind mid-scroll takes nothing")
    func abandoned() {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.scrolled(seen: 700, advice: .keepGoing)).state
        let outcome = state.handle(.dismiss)
        #expect(outcome.state.screen == .idle)
        #expect(outcome.state.scroll == nil)
        #expect(!outcome.effects.contains(.joinTheScroll))
    }

    @Test("Asking again while one is running does not start a second")
    func notReentrant() {
        var state = Self.choosing().handle(.choseScrollRegion(Self.region)).state
        state = state.handle(.captureScrolling).state
        #expect(state.screen == .idle)
    }

    @Test("Being told what was seen before one started changes nothing")
    func notScrolling() {
        let outcome = Self.app().handle(.scrolled(seen: 100, advice: .keepGoing))
        #expect(outcome.effects.isEmpty)
        #expect(outcome.state.scroll == nil)
    }
}
