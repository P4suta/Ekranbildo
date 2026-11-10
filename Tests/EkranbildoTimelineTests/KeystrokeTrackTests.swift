import EkranbildoContracts
import EkranbildoCore
import EkranbildoTimeline
import Testing

@Suite("Keystroke track")
struct KeystrokeTrackTests {

    private func typed(_ caps: [(Double, String)], modifiers: Modifiers = []) -> [Keystroke] {
        caps.map { Keystroke(at: .seconds($0.0), cap: $0.1, modifiers: modifiers) }
    }

    private func track(
        _ keys: [Keystroke],
        holdFor: Double = 1,
        joinWithin: Double = 1,
        mostCaps: Int = 8
    ) -> KeystrokeTrack {
        KeystrokeTrack(
            recorded: keys,
            holdFor: .seconds(holdFor),
            joinWithin: .seconds(joinWithin),
            mostCaps: mostCaps
        )
    }

    @Test("Nothing typed shows nothing")
    func nothingTyped() {
        #expect(track([]).showing(at: .seconds(1)).isEmpty)
    }

    @Test("Nothing is shown before the first key")
    func beforeTheFirstKey() {
        #expect(track(typed([(5, "A")])).showing(at: .seconds(4)).isEmpty)
    }

    @Test("A key is shown the moment it is pressed")
    func shownWhenPressed() {
        #expect(track(typed([(5, "A")])).showing(at: .seconds(5)) == ["A"])
    }

    @Test("A key stays up for as long as it is held for, and no longer")
    func heldForAWhile() {
        let one = track(typed([(5, "A")]), holdFor: 2)
        #expect(one.showing(at: .seconds(6.9)) == ["A"])
        #expect(one.showing(at: .seconds(7.1)).isEmpty)
    }

    @Test("Keys typed one after another are shown together, in the order they were typed")
    func typedTogether() {
        let word = track(typed([(1, "H"), (1.2, "E"), (1.4, "Y")]))
        #expect(word.showing(at: .seconds(1.4)) == ["H", "E", "Y"])
    }

    @Test("A pause starts the row over rather than growing it forever")
    func pauseStartsOver() {
        let two = track(typed([(1, "H"), (1.2, "I"), (9, "B")]), joinWithin: 1)
        #expect(two.showing(at: .seconds(9)) == ["B"])
    }

    @Test("Only the last few keys are kept, so the row never runs off the picture")
    func onlyTheLastFew() {
        let many = track(
            typed([(1, "A"), (1.1, "B"), (1.2, "C"), (1.3, "D")]), mostCaps: 2)
        #expect(many.showing(at: .seconds(1.3)) == ["C", "D"])
    }

    @Test("A key held down with a modifier is shown as the one thing it was")
    func modifiersJoinTheKey() {
        let saved = [Keystroke(at: .seconds(1), cap: "S", modifiers: [.command])]
        #expect(track(saved).showing(at: .seconds(1)) == ["⌘S"])
    }

    @Test("Modifiers are always written in the order Apple writes them in")
    func modifierOrder() {
        let all = [
            Keystroke(at: .seconds(1), cap: "4", modifiers: [.command, .shift, .control, .option])
        ]
        #expect(track(all).showing(at: .seconds(1)) == ["⌃⌥⇧⌘4"])
    }

    @Test("A key pressed with a modifier never joins the plain keys around it")
    func modifiedKeysStandAlone() {
        let mixed = [
            Keystroke(at: .seconds(1), cap: "A", modifiers: []),
            Keystroke(at: .seconds(1.1), cap: "S", modifiers: [.command]),
            Keystroke(at: .seconds(1.2), cap: "B", modifiers: []),
        ]
        let shown = track(mixed)
        #expect(shown.showing(at: .seconds(1.05)) == ["A"])
        #expect(shown.showing(at: .seconds(1.1)) == ["⌘S"])
        #expect(shown.showing(at: .seconds(1.2)) == ["B"])
    }

    @Test("The same recording always reads the same way")
    func deterministic() {
        let keys = typed([(1, "A"), (1.2, "B"), (4, "C")])
        let moments = [0.5, 1, 1.2, 2, 4, 6].map(Timestamp.seconds)
        let once = moments.map { track(keys).showing(at: $0) }
        let again = moments.map { track(keys).showing(at: $0) }
        #expect(once == again)
    }

    @Test("Keys that arrive out of order are read in the order they were typed")
    func reordered() {
        let jumbled = typed([(1.4, "Y"), (1, "H"), (1.2, "E")])
        #expect(track(jumbled).showing(at: .seconds(1.4)) == ["H", "E", "Y"])
    }

    @Test("Asking for a row that nothing is shown in costs nothing and says so")
    func quietMoment() {
        let gap = track(typed([(1, "A"), (9, "B")]), holdFor: 1, joinWithin: 1)
        #expect(gap.showing(at: .seconds(5)).isEmpty)
    }
}

@Suite("Keys on the timeline")
struct KeysOnTheTimelineTests {
    private func timeline(_ keys: KeystrokeTrack?) -> Timeline {
        Timeline(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 100),
            style: .standard,
            background: nil,
            duration: .seconds(10),
            tracks: [],
            keys: keys
        )
    }

    @Test("A recording with no keystrokes in it draws none")
    func noKeys() {
        #expect(timeline(nil).scene(at: .seconds(1)).keys.isEmpty)
    }

    @Test("The keys that were up at that moment are the ones on the picture")
    func keysAtAMoment() {
        let track = KeystrokeTrack(
            recorded: [Keystroke(at: .seconds(1), cap: "A", modifiers: [])],
            holdFor: .seconds(1)
        )
        #expect(timeline(track).scene(at: .seconds(1.5)).keys == ["A"])
        #expect(timeline(track).scene(at: .seconds(5)).keys.isEmpty)
    }

    @Test("Asking past the end of the recording reads the end, not nothing")
    func clampedToTheEnd() {
        let track = KeystrokeTrack(
            recorded: [Keystroke(at: .seconds(10), cap: "Z", modifiers: [])],
            holdFor: .seconds(1)
        )
        #expect(timeline(track).scene(at: .seconds(99)).keys == ["Z"])
    }
}

@Suite("Leaving the pointer alone")
struct LeavingThePointerAloneTests {
    private func wandering() -> [CursorSample] {
        (0..<Walk.steps).map { step in
            CursorSample(
                at: .seconds(Double(step) / Double(Walk.perSecond)),
                position: ScreenPoint(x: Double(step % Walk.wobble), y: Double(step)),
                pressed: step == Walk.clickAt
            )
        }
    }

    @Test("Asked not to smooth, the pointer is left exactly where it was")
    func notSmoothed() {
        let samples = wandering()
        #expect(CursorPolish(smooths: false).smooth(samples) == samples)
    }

    @Test("Asked to smooth, the pointer is moved")
    func smoothed() {
        let samples = wandering()
        #expect(CursorPolish(smooths: true).smooth(samples) != samples)
    }

    @Test("Asked not to show clicks, none are shown even though one happened")
    func noRipples() {
        #expect(CursorPolish(showsClicks: false).ripples(in: wandering()).isEmpty)
    }

    @Test("Asked to show clicks, the one that happened is shown")
    func ripples() {
        #expect(!CursorPolish(showsClicks: true).ripples(in: wandering()).isEmpty)
    }

    private enum Walk {
        static let steps = 30
        static let perSecond = 30
        static let wobble = 7
        static let clickAt = 10
    }
}
