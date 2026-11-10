@testable import DevKit
import Foundation
import Testing


@Suite("Stages")
struct StageTests {

    private func result(
        _ name: String,
        status: Int32 = 0,
        output: String = "",
        allowsDeprecation: String? = nil
    ) -> StageResult {
        StageResult(
            stage: Stage(name: name, allowsDeprecation: allowsDeprecation) { _ in
                Outcome(status: status, output: output)
            },
            outcome: Outcome(status: status, output: output)
        )
    }

    @Test("A stage that exits cleanly and says nothing passed")
    func cleanStagePasses() {
        #expect(result("Build").verdict == .passed)
    }

    @Test("A stage that exits with anything else failed")
    func nonZeroFails() {
        #expect(result("Build", status: 1).verdict == .failed)
    }

    @Test("A stage that mentions a deprecation failed even though it exited cleanly")
    func deprecationFails() {
        #expect(result("Build", output: "'foo' is deprecated").verdict == .deprecated)
    }

    @Test("Both spellings are caught", arguments: ["is deprecated", "deprecation warning"])
    func bothSpellings(text: String) {
        #expect(result("Build", output: text).verdict == .deprecated)
    }

    @Test("It is caught however it is capitalised")
    func caseDoesNotMatter() {
        #expect(result("Build", output: "DEPRECATED").verdict == .deprecated)
    }

    @Test("A stage that has written down why may say it")
    func allowedDeprecationPasses() {
        let allowed = result(
            "Dead code",
            output: "warning: 'native' is deprecated",
            allowsDeprecation: "Periphery needs an index store and only the old build writes one"
        )
        #expect(allowed.verdict == .passed)
    }

    @Test("An allowance has to say why")
    func allowanceMustGiveAReason() {
        #expect(
            Stage(name: "x", allowsDeprecation: "") { _ in Outcome(status: 0, output: "") }
                .allowsDeprecation == nil)
    }

    @Test("A stage that failed and mentioned a deprecation is reported as failed")
    func failureWinsOverDeprecation() {
        #expect(result("Build", status: 1, output: "is deprecated").verdict == .failed)
    }

    @Test("A stage that cannot even start is a failure, not a crash")
    func unstartableStageIsAFailure() {
        let stage = Stage(name: "Missing") { _ in
            throw Command.Failure(description: "no such file")
        }
        let result = StageResult(attempting: stage, in: Context(root: URL(fileURLWithPath: "/")))
        #expect(result.verdict == .failed)
        #expect(result.outcome.output.contains("no such file"))
    }

    @Test("A stage that starts is reported by what it did")
    func startableStageRuns() {
        let stage = Stage(name: "Fine") { _ in Outcome(status: 0, output: "hello") }
        let result = StageResult(attempting: stage, in: Context(root: URL(fileURLWithPath: "/")))
        #expect(result.verdict == .passed)
        #expect(result.outcome.output == "hello")
    }

    @Test("Applying corrections ends by building what they changed")
    func fixesEndWithABuild() throws {
        let stages = try Checks(root: URL(fileURLWithPath: "/"), brief: true).fixes()
        #expect(stages.last?.name == "Build")
    }

    @Test("And the corrections come first, or there is nothing to build")
    func fixesComeBeforeTheBuild() throws {
        let stages = try Checks(root: URL(fileURLWithPath: "/"), brief: true).fixes()
        #expect(stages.dropLast().allSatisfy { $0.name != "Build" })
        #expect(stages.count > 1)
    }


    @Test("A run of passes passed")
    func allPassed() {
        let run = RunSummary(results: [result("a"), result("b")])
        #expect(run.succeeded)
        #expect(run.failures.isEmpty)
    }

    @Test("A run names every stage that did not pass, in the order they ran")
    func failuresAreNamedInOrder() {
        let run = RunSummary(results: [
            result("a"),
            result("b", status: 1),
            result("c", output: "deprecated"),
        ])
        #expect(!run.succeeded)
        #expect(run.failures.map(\.stage.name) == ["b", "c"])
    }

    @Test("A deprecation is reported as what it is, not as a failure")
    func deprecationReadsDifferently() {
        let run = RunSummary(results: [result("c", output: "deprecated")])
        #expect(run.report.contains("deprecated"))
        #expect(!run.report.lowercased().contains("exited"))
    }

    @Test("An empty run is not a passing run")
    func emptyRunIsNotSuccess() {
        #expect(!RunSummary(results: []).succeeded)
    }
}
