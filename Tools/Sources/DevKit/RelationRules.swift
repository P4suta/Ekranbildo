import Foundation
import SwiftParser
import SwiftSyntax

public enum RelationRules {
    public static func findings(in source: String, path: String) -> [Finding] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let walker = Walker(path: path, locations: locations, source: source)
        walker.walk(tree)
        return walker.found.sorted { $0.line < $1.line }
    }

    static let marker = "relation:allow"
    static let nextMarker = "relation:allow:next"

    static let kept: Set<String> = ["private", "fileprivate"]

    static let advice =
        "Two things travel together here under no name but the positions they sit in. "
        + "Whoever reads one has to remember what the other means, and a third can be "
        + "added without anybody being asked. If they belong together, give it a name."

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

        override func visit(_ node: TupleTypeSyntax) -> SyntaxVisitorContinueKind {
            guard node.elements.count > 1, Self.crossesAFileBoundary(node) else {
                return .visitChildren
            }
            let line = locations.location(
                for: node.positionAfterSkippingLeadingTrivia
            ).line
            guard !allowed(line) else { return .visitChildren }
            found.append(Finding(path: path, line: line, advice: RelationRules.advice))
            return .visitChildren
        }

        static func crossesAFileBoundary(_ node: TupleTypeSyntax) -> Bool {
            guard !Self.isInsideABody(node) else { return false }
            var walk = node.parent
            while let here = walk {
                if let modifiers = Self.modifiers(of: here) {
                    return !modifiers.contains { RelationRules.kept.contains($0) }
                }
                walk = here.parent
            }
            return false
        }

        static func isInsideABody(_ node: TupleTypeSyntax) -> Bool {
            var walk = node.parent
            while let here = walk {
                if here.is(CodeBlockSyntax.self) { return true }
                walk = here.parent
            }
            return false
        }

        static func modifiers(of node: Syntax) -> [String]? {
            if let function = node.as(FunctionDeclSyntax.self) {
                return function.modifiers.map { $0.name.text }
            }
            if let variable = node.as(VariableDeclSyntax.self) {
                return variable.modifiers.map { $0.name.text }
            }
            if let initialiser = node.as(InitializerDeclSyntax.self) {
                return initialiser.modifiers.map { $0.name.text }
            }
            if let subscripted = node.as(SubscriptDeclSyntax.self) {
                return subscripted.modifiers.map { $0.name.text }
            }
            if node.as(TypeAliasDeclSyntax.self) != nil { return [] }
            return nil
        }

        func allowed(_ line: Int) -> Bool {
            let here = lines.indices.contains(line - 1) ? lines[line - 1] : ""
            let above = lines.indices.contains(line - 2) ? lines[line - 2] : ""
            return here.contains(RelationRules.marker)
                || above.contains(RelationRules.nextMarker)
        }
    }
}
