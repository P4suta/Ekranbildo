@testable import DevKit
import Foundation
import Testing


@Suite("Running a command")
struct CommandTests {

    @Test("What it printed comes back")
    func outputComesBack() throws {
        let outcome = try Command.run("/bin/echo", ["hello"], in: URL(fileURLWithPath: "/"))
        #expect(outcome.output.contains("hello"))
        #expect(outcome.status == 0)
    }

    @Test("What it printed on the way down comes back too")
    func standardErrorComesBack() throws {
        let outcome = try Command.run(
            "/bin/sh", ["-c", "echo trouble >&2; exit 3"], in: URL(fileURLWithPath: "/"))
        #expect(outcome.output.contains("trouble"))
        #expect(outcome.status == 3)
    }

    @Test("A large output is searched without a pipe deciding the answer")
    func largeOutputIsSearched() throws {
        let needle = "findMe"
        let outcome = try Command.run(
            "/bin/sh",
            ["-c", "for i in $(seq 1 20000); do echo padding line $i; done; echo \(needle)"],
            in: URL(fileURLWithPath: "/")
        )
        #expect(outcome.output.utf8.count > 200_000)
        #expect(outcome.holds(needle))
    }

    @Test("A needle that is not there is not found")
    func absentNeedle() throws {
        let outcome = try Command.run("/bin/echo", ["hay"], in: URL(fileURLWithPath: "/"))
        #expect(!outcome.holds("needle"))
    }

    @Test("A command that does not exist is an error rather than a silent zero")
    func missingCommandThrows() {
        #expect(throws: (any Error).self) {
            try Command.run("/no/such/tool", [], in: URL(fileURLWithPath: "/"))
        }
    }

    @Test("A command that outruns the pipe buffer still finishes")
    func largeOutputDoesNotDeadlock() throws {
        let outcome = try Command.run(
            "/bin/sh", ["-c", "for i in $(seq 1 50000); do echo line $i; done"],
            in: URL(fileURLWithPath: "/")
        )
        #expect(outcome.status == 0)
        #expect(outcome.output.contains("line 50000"))
    }

    @Test("It runs where it was told to")
    func runsInTheGivenDirectory() throws {
        let outcome = try Command.run("/bin/pwd", [], in: URL(fileURLWithPath: "/usr"))
        #expect(outcome.output.contains("/usr"))
    }
}
