@testable import DevKit
import Testing

@Suite("Where a number may be written")
struct LiteralTests {

    private func findings(_ source: String) -> [Finding] {
        LiteralRules.findings(in: source, path: "Example.swift")
    }

    @Test("A number given a name is not a finding, however it is wrapped")
    func named() {
        #expect(findings("static let gap = 8").isEmpty)
        #expect(findings("let lengths: [Double] = [28, 44, 64]").isEmpty)
        #expect(findings("static let pause = Timestamp.seconds(0.35)").isEmpty)
        #expect(
            findings("static let tint = Color(red: 0.42, green: 0.47, blue: 0.78)").isEmpty)
        #expect(findings("private static let dark = (red: UInt8(24), green: UInt8(28))").isEmpty)
    }

    @Test("A number in an enum's raw value is not a finding")
    func rawValues() {
        #expect(findings("enum Level: Int { case low = 3, high = 9 }").isEmpty)
    }

    @Test("A number with no name anywhere near it is a finding")
    func buried() {
        #expect(!findings("draw(at: 42)").isEmpty)
        #expect(!findings("if count > 7 { return }").isEmpty)
        #expect(!findings("return width - 17").isEmpty)
    }

    @Test("A number a name is computed from is not a finding")
    func computedNames() {
        #expect(findings("static let thirds = 4.0 / 3.0").isEmpty)
        #expect(findings("static let half = width / 2").isEmpty)
    }

    @Test("Zero and one are never a finding")
    func trivial() {
        #expect(findings("let empty = things.count == 0").isEmpty)
        #expect(findings("let next = index + 1").isEmpty)
        #expect(findings("let back = index - 1").isEmpty)
    }

    @Test("A number in a test is a number somebody is asserting about")
    func inTests() {
        #expect(
            LiteralRules.findings(
                in: "#expect(rect.width == 300)", path: "Tests/Example.swift"
            ).isEmpty)
    }

    @Test("Every finding says where it is")
    func located() throws {
        let found = findings("let a = 1\nif count > 7 { return }")
        #expect(found.count == 1)
        #expect(try #require(found.first).line == 2)
    }

    @Test("A marker allows one")
    func marker() {
        #expect(findings("// number:allow:next it is the code\ndraw(at: 42)").isEmpty)
    }
}
