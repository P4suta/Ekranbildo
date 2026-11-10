import EkranbildoGeometry
import EkranbildoObservability
@testable import EkranbildoSignposts
import Testing

@Suite("Signposting")
struct SignpostingTests {

    @Test("Nothing is emitted unless it was asked for")
    func offByDefault() {
        #expect(Signposting.emitter(environment: Lookup()) is NoSignposts)
    }

    @Test("It is asked for by name", arguments: ["1", "true", "TRUE"])
    func onWhenAsked(value: String) {
        #expect(Signposting.emitter(environment: Lookup(["EKRANBILDO_SIGNPOSTS": value])) is SystemSignposts)
    }

    @Test("Anything else is off", arguments: ["0", "", "yes", "no"])
    func offOtherwise(value: String) {
        #expect(Signposting.emitter(environment: Lookup(["EKRANBILDO_SIGNPOSTS": value])) is NoSignposts)
    }

    @Test("Emitting returns")
    func emittingReturns() {
        let emitter = SystemSignposts()
        emitter.began("solve")
        emitter.happened("placed")
        emitter.ended("solve")
    }
}
