import EkranbildoApp
import EkranbildoContracts
import EkranbildoLibrary
import EkranbildoShell
import Testing

@Suite("Polishing a recording before it is written")
struct PolishingARecordingTests {

    private static func app(_ change: (inout Settings) -> Void = { _ in }) -> AppState {
        var settings = Settings()
        change(&settings)
        return AppState(library: Library(), permission: .granted, settings: settings)
    }

    private static let region = ScreenRect(x: 0, y: 0, width: 640, height: 480)

    private static func stopped(
        _ change: (inout Settings) -> Void = { _ in }
    ) -> (state: AppState, effects: [AppEffect]) {
        var state = app(change).handle(.record).state
        state = state.handle(.choseRecordingRegion(Self.region)).state
        let outcome = state.handle(.stopRecording)
        return (outcome.state, outcome.effects)
    }

    private func polish(_ effects: [AppEffect]) -> Polish? {
        effects.compactMap { effect -> Polish? in
            guard case .finishRecording(let polish) = effect else { return nil }
            return polish
        }.first
    }

    @Test("A recording is smoothed and its clicks are shown, by default")
    func polishedByDefault() throws {
        let asked = try #require(polish(Self.stopped().effects))
        #expect(asked.wants(.smoothThePointer))
        #expect(asked.wants(.showClicks))
    }

    @Test("The parts where nothing happened are cut, by default")
    func cutsByDefault() throws {
        #expect(try #require(polish(Self.stopped().effects)).wants(.cutDeadTime))
    }

    @Test("Turning the smoothing off asks for none")
    func smoothingOff() throws {
        let effects = Self.stopped { $0.turn(.smoothThePointer, on: false) }.effects
        let asked = try #require(polish(effects))
        #expect(!asked.wants(.smoothThePointer))
        #expect(asked.wants(.showClicks))
        #expect(asked.wants(.cutDeadTime))
    }

    @Test("Turning the clicks off asks for none")
    func clicksOff() throws {
        let effects = Self.stopped { $0.turn(.showClicks, on: false) }.effects
        let asked = try #require(polish(effects))
        #expect(!asked.wants(.showClicks))
        #expect(asked.wants(.smoothThePointer))
    }

    @Test("Turning the cutting off asks for none")
    func cuttingOff() throws {
        let effects = Self.stopped { $0.turn(.cutDeadTime, on: false) }.effects
        let asked = try #require(polish(effects))
        #expect(!asked.wants(.cutDeadTime))
        #expect(asked.wants(.smoothThePointer))
    }

    @Test("Turning everything off still writes the recording down")
    func allOff() throws {
        let effects = Self.stopped {
            $0.turn(.smoothThePointer, on: false)
            $0.turn(.showClicks, on: false)
            $0.turn(.cutDeadTime, on: false)
        }.effects
        #expect(polish(effects) != nil)
    }
}
