@testable import DevKit
import Foundation
import Testing


@Suite("Finding the toolchain")
struct ToolchainTests {

    @Test("A tool on the path is found")
    func findsWhatIsThere() throws {
        #expect(try Toolchain.locate("echo").path().hasSuffix("echo"))
    }

    @Test("A tool that is not there is reported by name")
    func missingToolIsNamed() {
        #expect(throws: (any Error).self) {
            try Toolchain.locate("definitely-not-a-real-tool-xyzzy")
        }
    }

    @Test("Everything a run needs is found before the run starts")
    func everythingIsFoundUpFront() throws {
        let missing = Toolchain.missing(from: ["echo", "ls", "definitely-not-a-real-tool-xyzzy"])
        #expect(missing == ["definitely-not-a-real-tool-xyzzy"])
    }

    @Test("A run whose tools are all present reports nothing missing")
    func nothingMissing() {
        #expect(Toolchain.missing(from: ["echo", "ls"]).isEmpty)
    }
}
