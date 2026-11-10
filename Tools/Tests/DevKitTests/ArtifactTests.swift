@testable import DevKit
import Testing


@Suite("What ships")
struct ArtifactTests {

    private let names = [
        ForbiddenName(symbol: "EkranbildoTestHooks", reason: "the control channel"),
        ForbiddenName(symbol: "HookSession", reason: "the channel's session"),
    ]

    @Test("A name present in the release build is a finding")
    func presentInReleaseIsAFinding() {
        let found = ArtifactRules.check(
            debug: "EkranbildoTestHooks HookSession", release: "EkranbildoTestHooks", names: names)
        #expect(found.count == 1)
        #expect(found[0].advice.contains("EkranbildoTestHooks"))
    }

    @Test("A name absent from release and present in debug is right")
    func absentFromReleaseIsRight() {
        #expect(
            ArtifactRules.check(
                debug: "EkranbildoTestHooks HookSession", release: "nothing", names: names
            ).isEmpty)
    }

    @Test("A name absent from both is a finding, not a pass")
    func absentFromBothIsAFinding() {
        let found = ArtifactRules.check(debug: "nothing", release: "nothing", names: names)
        #expect(found.count == 2)
        #expect(found[0].advice.contains("proves nothing"))
    }

    @Test("A name is found in a haystack too large for a pipe")
    func largeHaystack() {
        let padding = String(repeating: "unrelated symbol name\n", count: 200_000)
        let found = ArtifactRules.check(
            debug: padding + "HookSession",
            release: padding + "HookSession",
            names: [ForbiddenName(symbol: "HookSession", reason: "the channel's session")]
        )
        #expect(found.count == 1)
    }

    @Test("Every finding says which name and why it matters")
    func findingsRead() {
        let found = ArtifactRules.check(debug: "", release: "", names: names)
        #expect(found.allSatisfy { !$0.advice.isEmpty })
    }
}


@Suite("Which product each name is checked in")
struct ForbiddenProductTests {

    private let names = [
        ForbiddenName(symbol: "InTheTool", reason: "a tool one"),
        ForbiddenName(symbol: "InTheApp", product: "ekranbildo-app", reason: "an app one"),
        ForbiddenName(symbol: "AlsoInTheApp", product: "ekranbildo-app", reason: "another app one"),
    ]

    @Test("A name says nothing about a product it does not belong to")
    func namesBelongToOneProduct() {
        #expect(ArtifactRules.names(in: "ekranbildo-app", among: names).map(\.symbol)
            == ["InTheApp", "AlsoInTheApp"])
        #expect(ArtifactRules.names(in: "ekranbildo-cli", among: names).map(\.symbol) == ["InTheTool"])
    }

    @Test("Every product with something to check is named once")
    func productsAreDistinct() {
        #expect(ArtifactRules.products(of: names) == ["ekranbildo-app", "ekranbildo-cli"])
    }

    @Test("The order does not depend on how the names were written")
    func orderIsStable() {
        #expect(ArtifactRules.products(of: names) == ArtifactRules.products(of: names.reversed()))
    }

    @Test("Nothing forbidden is nothing to build")
    func nothingForbidden() {
        #expect(ArtifactRules.products(of: []).isEmpty)
    }

    @Test("The application is among the products actually checked")
    func theApplicationIsChecked() {
        #expect(ArtifactRules.products(of: ArtifactRules.forbidden).contains("ekranbildo-app"))
    }
}
