import Foundation
import SwiftParser
import SwiftSyntax

public enum RebuildRules {
    public static func findings(
        in source: String,
        path: String,
        protecting protected: Set<String> = []
    ) -> [Finding] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let walker = Walker(
            path: path, locations: locations, source: source, protected: protected)
        walker.walk(tree)
        return walker.found.sorted { $0.line < $1.line }
    }

    public static func protectedTypes(in source: String) -> Set<String> {
        let tree = Parser.parse(source: source)
        let walker = Offering(viewMode: .sourceAccurate)
        walker.walk(tree)
        return walker.found
    }

    private final class Offering: SyntaxVisitor {
        var found: Set<String> = []

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard node.name.text == "replacing" else { return .visitChildren }
            var parent = node.parent
            while let node = parent {
                if let declared = Self.name(of: node) {
                    found.insert(declared)
                    break
                }
                parent = node.parent
            }
            return .visitChildren
        }

        static func name(of node: Syntax) -> String? {
            if let structure = node.as(StructDeclSyntax.self) { return structure.name.text }
            if let object = node.as(ClassDeclSyntax.self) { return object.name.text }
            if let choice = node.as(EnumDeclSyntax.self) { return choice.name.text }
            if let extended = node.as(ExtensionDeclSyntax.self) {
                return extended.extendedType.trimmedDescription
            }
            return nil
        }
    }

    static let marker = "rebuild:allow"
    static let nextMarker = "rebuild:allow:next"

    static func advice(type: String, value: String) -> String {
        "\(type) is built here out of \(value)'s own fields, and \(type) has a `replacing` "
            + "method for exactly this. A rebuild carries what whoever wrote it named, so "
            + "whatever is added to \(type) later is dropped here, silently, by code that was "
            + "right the day it was written. Call `\(value).replacing(...)`."
    }

    private final class Walker: SyntaxVisitor {
        let path: String
        let locations: SourceLocationConverter
        let lines: [String]
        let protected: Set<String>
        var found: [Finding] = []

        init(
            path: String,
            locations: SourceLocationConverter,
            source: String,
            protected: Set<String>
        ) {
            self.path = path
            self.locations = locations
            self.protected = protected
            lines = source.components(separatedBy: "\n")
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let called = node.calledExpression.as(DeclReferenceExprSyntax.self) else {
                return .visitChildren
            }
            let type = called.baseName.text
            guard protected.contains(type) else { return .visitChildren }

            var perValue: [String: Int] = [:]
            for argument in node.arguments {
                guard let root = Self.rootOfMemberAccess(argument.expression) else { continue }
                perValue[root, default: 0] += 1
            }
            guard let culprit = perValue.filter({ $0.value >= Self.enoughToBeACopy })
                .map(\.key).sorted().first
            else { return .visitChildren }

            let line = locations.location(for: node.positionAfterSkippingLeadingTrivia).line
            guard !allowed(line) else { return .visitChildren }
            found.append(
                Finding(path: path, line: line, advice: RebuildRules.advice(type: type, value: culprit)))
            return .visitChildren
        }

        static let enoughToBeACopy = 2

        static func rootOfMemberAccess(_ expression: ExprSyntax) -> String? {
            guard var member = expression.as(MemberAccessExprSyntax.self) else { return nil }
            while let base = member.base {
                if let deeper = base.as(MemberAccessExprSyntax.self) {
                    member = deeper
                    continue
                }
                guard let reference = base.as(DeclReferenceExprSyntax.self) else { return nil }
                let name = reference.baseName.text
                return name.first?.isUppercase == true ? nil : name
            }
            return nil
        }

        func allowed(_ line: Int) -> Bool {
            guard line >= 1, line <= lines.count else { return false }
            if lines[line - 1].contains(RebuildRules.marker) { return true }
            guard line >= 2 else { return false }
            return lines[line - 2].contains(RebuildRules.nextMarker)
        }
    }
}
