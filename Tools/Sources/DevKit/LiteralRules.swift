import Foundation
import SwiftParser
import SwiftSyntax

public enum LiteralRules {
    public static func findings(in source: String, path: String) -> [Finding] {
        guard !isATest(path) else { return [] }
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let walker = Walker(path: path, locations: locations, source: source)
        walker.walk(tree)
        return walker.found.sorted { $0.line < $1.line }
    }

    static func isATest(_ path: String) -> Bool {
        path.hasPrefix("Tests/") || path.contains("/Tests/")
    }

    static let marker = "number:allow"
    static let nextMarker = "number:allow:next"

    static let trivial: Set<String> = ["0", "1"]

    static let advice =
        "A number written here cannot be changed in one place, compared against an "
        + "alternative, or pinned by a golden. Give it a name."

    private final class Walker: SyntaxVisitor {
        let path: String
        let locations: SourceLocationConverter
        let lines: [String]
        var found: [Finding] = []

        init(path: String, locations: SourceLocationConverter, source: String) {
            self.path = path
            self.locations = locations
            lines = source.components(separatedBy: "\n")
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: IntegerLiteralExprSyntax) -> SyntaxVisitorContinueKind {
            consider(node.literal.text, at: Syntax(node))
            return .visitChildren
        }

        override func visit(_ node: FloatLiteralExprSyntax) -> SyntaxVisitorContinueKind {
            consider(node.literal.text, at: Syntax(node))
            return .visitChildren
        }

        private func consider(_ text: String, at node: Syntax) {
            guard !LiteralRules.trivial.contains(text.replacingOccurrences(of: "_", with: ""))
            else { return }
            guard !Self.hasAName(node) else { return }
            let line = locations.location(for: node.positionAfterSkippingLeadingTrivia).line
            guard !allowed(line) else { return }
            found.append(Finding(path: path, line: line, advice: LiteralRules.advice))
        }

        static func hasAName(_ node: Syntax) -> Bool {
            var parent = node.parent
            while let here = parent {
                if here.is(PatternBindingSyntax.self) { return true }
                if here.is(InitializerClauseSyntax.self) { return true }
                if here.is(EnumCaseElementSyntax.self) { return true }
                if here.is(CodeBlockSyntax.self) { return false }
                parent = here.parent
            }
            return false
        }

        func allowed(_ line: Int) -> Bool {
            guard line >= 1, line <= lines.count else { return false }
            if lines[line - 1].contains(LiteralRules.marker) { return true }
            guard line >= 2 else { return false }
            return lines[line - 2].contains(LiteralRules.nextMarker)
        }
    }
}
