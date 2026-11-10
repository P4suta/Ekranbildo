@testable import DevKit
import Testing


@Suite("Imports")
struct ImportTests {

    private func imports(_ source: String) -> [String] {
        ImportRules.imports(in: source).map(\.module)
    }

    @Test("An import is found")
    func findsAnImport() {
        #expect(imports("import Foundation") == ["Foundation"])
    }

    @Test("Several come back in the order they were written")
    func keepsOrder() {
        #expect(imports("import B\nimport A") == ["B", "A"])
    }

    @Test("Text inside a string literal is not an import")
    func stringLiteralIsNotAnImport() {
        #expect(imports(#"let sample = "import Vision""#).isEmpty)
    }

    @Test("Text inside a multi-line string literal is not an import")
    func multiLineStringIsNotAnImport() {
        let source = """
            let sample = \"\"\"
                import ScreenCaptureKit
                \"\"\"
            """
        #expect(imports(source).isEmpty)
    }

    @Test("A comment is not an import")
    func commentIsNotAnImport() {
        #expect(imports("// import Vision\n/* import AppKit */").isEmpty)
    }

    @Test("An import behind a condition is still an import")
    func conditionalImportCounts() {
        #expect(imports("#if canImport(AppKit)\nimport AppKit\n#endif") == ["AppKit"])
    }

    @Test("Only the first component of a submodule import is the module")
    func submoduleReportsItsModule() {
        #expect(imports("import Foundation.NSString") == ["Foundation"])
    }

    @Test("A kinded import is still an import")
    func kindedImport() {
        #expect(imports("import struct Foundation.Data") == ["Foundation"])
    }

    @Test("An attributed import is still an import")
    func attributedImport() {
        #expect(imports("@preconcurrency import Foundation") == ["Foundation"])
    }


    @Test(
        "A core module may not reach an interface framework",
        arguments: [
            "AppKit", "SwiftUI", "CoreGraphics", "Vision", "ScreenCaptureKit", "AVFoundation",
        ])
    func coreModulesAreKeptPure(framework: String) {
        let found = ImportRules.forbidden(
            imports: [Import(module: framework, line: 1)], in: "EkranbildoCore")
        #expect(found.count == 1)
    }

    @Test("A module that ships an interface may")
    func othersMay() {
        #expect(
            ImportRules.forbidden(
                imports: [Import(module: "AppKit", line: 1)], in: "EkranbildoOverlay"
            ).isEmpty)
    }

    @Test("The pure module may not even reach Foundation")
    func theLeafIsPure() {
        #expect(
            ImportRules.forbidden(
                imports: [Import(module: "Foundation", line: 1)], in: "EkranbildoGeometry"
            ).count == 1)
    }

    @Test(
        "Observability and the editor are on the list too",
        arguments: [
            "EkranbildoObservability", "EkranbildoEditor",
        ])
    func theLongerListIsUsed(module: String) {
        #expect(
            ImportRules.forbidden(imports: [Import(module: "AppKit", line: 1)], in: module)
                .count == 1)
    }

    @Test("Another core module may reach Foundation")
    func othersMayReachFoundation() {
        #expect(
            ImportRules.forbidden(
                imports: [Import(module: "Foundation", line: 1)], in: "EkranbildoCore"
            ).isEmpty)
    }

    @Test("A finding says where it is and what was reached")
    func findingReads() throws {
        let found = try #require(
            ImportRules.forbidden(imports: [Import(module: "Vision", line: 7)], in: "EkranbildoCore")
                .first)
        #expect(found.line == 7)
        #expect(found.advice.contains("Vision"))
    }
}
