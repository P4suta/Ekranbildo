@testable import DevKit
import Testing


@Suite("Fuzzing")
struct FuzzingTests {

    @Test("The build asks for the fuzzer and the address sanitiser")
    func buildAsksForBoth() {
        let command = Fuzzing.buildCommand
        #expect(command.contains("-sanitize=fuzzer,address"))
    }

    @Test("The build defines the flag the entry point is behind")
    func buildDefinesTheFlag() {
        #expect(Fuzzing.buildCommand.contains("-DEKRANBILDO_FUZZ"))
    }

    @Test("It builds the library, not an executable")
    func buildsTheLibrary() {
        #expect(Fuzzing.buildCommand.contains("EkranbildoFuzz"))
        #expect(!Fuzzing.buildCommand.contains("--product ekranbildo-cli"))
    }

    @Test("The link pulls the archive in whole")
    func linkIsWhole() {
        let command = Fuzzing.linkCommand(binaryPath: "/tmp/bin")
        #expect(command.contains("--whole-archive"))
        #expect(command.contains("--no-whole-archive"))
    }

    @Test("The link asks for the fuzzer too")
    func linkAsksForTheFuzzer() {
        #expect(Fuzzing.linkCommand(binaryPath: "/tmp/bin").contains("-sanitize=fuzzer,address"))
    }

    @Test("The whole script runs the binary it just linked")
    func scriptRunsWhatItBuilt() {
        let script = Fuzzing.script(runs: 1000, seconds: nil)
        #expect(script.contains("-runs=1000"))
    }

    @Test("It is bounded by runs or by seconds, and says which")
    func boundedEitherWay() {
        #expect(Fuzzing.script(runs: 500, seconds: nil).contains("-runs=500"))
        #expect(Fuzzing.script(runs: nil, seconds: 60).contains("-max_total_time=60"))
    }

    @Test("A run with no bound at all is refused")
    func unboundedIsRefused() {
        #expect(Fuzzing.script(runs: nil, seconds: nil).contains("-runs="))
    }

    @Test("The container image is pinned")
    func imageIsPinned() {
        #expect(Fuzzing.image.contains(":"))
        #expect(!Fuzzing.image.hasSuffix(":latest"))
    }
}
