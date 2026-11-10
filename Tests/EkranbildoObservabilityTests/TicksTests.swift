import EkranbildoObservability
import Testing

@Suite("A manual clock can be read without moving")
struct ManualTickReadingTests {

    @Test("Reading through now() moves the clock")
    func nowMoves() {
        var ticks = ManualTickSource()
        let first = ticks.now()
        #expect(ticks.now() != first)
    }

    @Test("Asking what is next does not")
    func nextDoesNot() {
        var ticks = ManualTickSource()
        let before = ticks.next
        #expect(ticks.next == before)
        #expect(ticks.now() == before)
    }

    @Test("Advancing by an amount moves it by exactly that amount")
    func advancesByWhatItIsTold() {
        var ticks = ManualTickSource()
        let before = ticks.next
        ticks.advance(by: TickInterval(nanoseconds: 500))
        #expect(ticks.next.nanoseconds == before.nanoseconds + 500)
    }
}
