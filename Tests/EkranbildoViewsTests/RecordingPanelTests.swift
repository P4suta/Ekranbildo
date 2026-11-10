@testable import EkranbildoViews
import Testing

@Suite("What a recording says about itself")
struct RecordingPanelTests {

    @Test(
        "The time is minutes and seconds",
        arguments: [(0.0, "0:00"), (9.0, "0:09"), (61.0, "1:01"), (600.0, "10:00")]
    )
    func clock(_ seconds: Double, _ said: String) {
        #expect(RecordingPanelView.clock(seconds) == said)
    }

    @Test("Part of a second is not a second")
    func partSeconds() {
        #expect(RecordingPanelView.clock(9.9) == "0:09")
    }

    @Test("A long recording still reads as a time")
    func longOne() {
        #expect(RecordingPanelView.clock(3661) == "61:01")
    }
}
