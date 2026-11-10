import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import Testing

@Suite("A diagnostic report")
struct DiagnosticsReportTests {

    private var report: String { Diagnostics.html(of: SceneLibrary.sampleAnnotated) }

    @Test("It is a page somebody can open")
    func isAPage() {
        #expect(report.contains("<html") || report.contains("<section"))
    }

    @Test("It says what the solver decided")
    func saysWhatHappened() {
        #expect(report.contains("Result"))
    }

    @Test("The same scene reports the same page")
    func reproducible() {
        let once = report
        let again = report
        #expect(once == again)
    }

    @Test("A scene with no annotations still reports")
    func empty() {
        let bare = Scene(
            canvas: SceneRect(x: 0, y: 0, width: 100, height: 100),
            background: nil,
            annotations: [],
            style: .standard
        )
        #expect(!Diagnostics.html(of: bare).isEmpty)
    }

    @Test("What a synthesised scene reports says none of the original words")
    func synthesised() {
        let original = SceneLibrary.sampleAnnotated
        let words = original.annotations.map(\.label).filter { $0.count > 3 }
        let said = Diagnostics.html(of: Synthesis().synthesised(original))
        for word in words {
            #expect(!said.contains(word), "the report still says \(word)")
        }
    }
}
