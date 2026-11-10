@testable import DevKit
import Testing

@Suite("What it may be used for")
struct LicenceTests {
    private func findings(readme: String, present: [String]) -> [Finding] {
        LicenceRules.findings(readme: readme, files: Set(present))
    }

    private let both = "Licensed under either of LICENSE-APACHE or LICENSE-MIT at your option."

    @Test("Both licences offered and both written down is the whole of it")
    func inOrder() {
        #expect(findings(readme: both, present: LicenceRules.offered).isEmpty)
    }

    @Test("A licence offered but not written down leaves nobody able to read it")
    func missingFile() {
        let found = findings(readme: both, present: ["LICENSE-MIT"])
        #expect(found.count == 1)
        #expect(found.first?.advice.contains("LICENSE-APACHE") == true)
    }

    @Test("A licence written down but not offered is a file nobody is pointed at")
    func unmentioned() {
        let found = findings(readme: "Licensed under LICENSE-MIT.", present: LicenceRules.offered)
        #expect(found.count == 1)
        #expect(found.first?.advice.contains("LICENSE-APACHE") == true)
    }

    @Test("Saying nothing about it at all is the worst of the three")
    func silent() {
        #expect(findings(readme: "# Ekranbildo", present: []).count == LicenceRules.offered.count)
    }

    @Test("Every licence offered is named in the advice, so nobody has to guess which")
    func namesThem() {
        for licence in LicenceRules.offered {
            let found = findings(readme: "# Ekranbildo", present: [])
            #expect(found.contains { $0.advice.contains(licence) })
        }
    }
}
