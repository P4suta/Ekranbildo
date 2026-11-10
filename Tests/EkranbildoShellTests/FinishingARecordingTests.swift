import EkranbildoShell
import Testing

@Suite("Finishing a recording")
struct FinishingARecordingTests {

    @Test("Every way of finishing a recording can be asked for on its own")
    func eachOnItsOwn() {
        for step in Finishing.allCases {
            let only = Polish(wanted: [step])
            #expect(only.wants(step))
            for other in Finishing.allCases where other != step {
                #expect(!only.wants(other), "\(step) alone should not bring \(other)")
            }
        }
    }

    @Test("Wanting nothing wants none of them")
    func nothing() {
        let none = Polish(wanted: [])
        for step in Finishing.allCases {
            #expect(!none.wants(step))
        }
    }

    @Test("Every way of finishing has a setting behind it")
    func everyStepIsSettable() {
        for step in Finishing.allCases {
            var settings = Settings()
            settings.turn(step, on: false)
            #expect(!settings.polish.wants(step))
            settings.turn(step, on: true)
            #expect(settings.polish.wants(step))
        }
    }

    @Test("The settings as a whole say the same thing as each setting on its own")
    func settingsAgree() {
        var settings = Settings()
        settings.smoothsThePointer = true
        settings.showsClicks = false
        settings.showsKeystrokes = true
        settings.cutsDeadTime = false

        let polish = settings.polish
        #expect(polish.wants(.smoothThePointer))
        #expect(!polish.wants(.showClicks))
        #expect(polish.wants(.showKeystrokes))
        #expect(!polish.wants(.cutDeadTime))
    }

    @Test("Asking for everything asks for every one of them")
    func everything() {
        let all = Polish(wanted: Finishing.allCases)
        for step in Finishing.allCases {
            #expect(all.wants(step))
        }
    }

    @Test("Asking twice for the same thing is asking for it once")
    func noDuplicates() {
        let twice = Polish(wanted: [.showClicks, .showClicks])
        #expect(twice == Polish(wanted: [.showClicks]))
    }

    @Test("The order it was asked for in does not change what was asked for")
    func orderDoesNotMatter() {
        #expect(
            Polish(wanted: [.showClicks, .cutDeadTime])
                == Polish(wanted: [.cutDeadTime, .showClicks]))
    }
}
