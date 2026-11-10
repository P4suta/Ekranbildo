import Foundation
import SwiftParser
import SwiftSyntax

public enum ChoiceRules {
    public static func findings(
        in source: String,
        path: String,
        ours: Set<String>
    ) -> [Finding] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let walker = Walker(path: path, locations: locations, ours: ours)
        walker.walk(tree)
        return walker.found.sorted { $0.line < $1.line }
    }

    public static func casesWeDeclare(in source: String) -> Set<String> {
        let tree = Parser.parse(source: source)
        let walker = Declared(viewMode: .sourceAccurate)
        walker.walk(tree)
        return walker.found
    }

    private final class Declared: SyntaxVisitor {
        var found: Set<String> = []

        override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
            for element in node.elements {
                found.insert(element.name.text)
            }
            return .visitChildren
        }
    }

    static let theirs = "unknown"

    static let advice =
        "This switch decides by naming cases, and then lets everything it did not name fall "
        + "into one place. A case added later lands there without anybody being asked, which "
        + "is how an option gets written, threaded through and silently never acted on. Name "
        + "every case, and let the compiler ask the question when a new one arrives."

    private final class Walker: SyntaxVisitor {
        let path: String
        let locations: SourceLocationConverter
        let ours: Set<String>
        var found: [Finding] = []

        init(path: String, locations: SourceLocationConverter, ours: Set<String>) {
            self.path = path
            self.locations = locations
            self.ours = ours
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
            let cases = node.cases.compactMap { $0.as(SwitchCaseSyntax.self) }
            guard cases.contains(where: { namesOneOfOurs($0) }) else { return .visitChildren }
            guard let catchAll = cases.first(where: Self.catchesTheRest) else {
                return .visitChildren
            }
            let line = locations.location(
                for: catchAll.positionAfterSkippingLeadingTrivia
            ).line
            found.append(Finding(path: path, line: line, advice: ChoiceRules.advice))
            return .visitChildren
        }

        func namesOneOfOurs(_ node: SwitchCaseSyntax) -> Bool {
            guard Self.namesACase(node) else { return false }
            return Self.named(in: node).contains { ours.contains($0) }
        }

        static func named(in node: SwitchCaseSyntax) -> [String] {
            patterns(of: node).compactMap { pattern in
                let written = pattern.trimmedDescription
                guard let dot = written.firstIndex(of: ".") else { return nil }
                let after = written[written.index(after: dot)...]
                let name = after.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                return name.isEmpty ? nil : String(name)
            }
        }

        static func namesACase(_ node: SwitchCaseSyntax) -> Bool {
            patterns(of: node).contains { $0.is(ExpressionPatternSyntax.self)
                && $0.trimmedDescription.hasPrefix(".")
                || $0.as(ValueBindingPatternSyntax.self)?.pattern
                    .is(ExpressionPatternSyntax.self) == true
                    && $0.trimmedDescription.contains(".")
            }
        }

        static func catchesTheRest(_ node: SwitchCaseSyntax) -> Bool {
            if node.label.as(SwitchDefaultLabelSyntax.self) != nil {
                return !Self.namesSomebodyElsesCases(node)
            }
            let all = patterns(of: node)
            guard all.count == 1, let only = all.first else { return false }
            if only.is(WildcardPatternSyntax.self) { return true }
            if only.is(IdentifierPatternSyntax.self) { return true }
            if let bound = only.as(ValueBindingPatternSyntax.self) {
                return bound.pattern.is(IdentifierPatternSyntax.self)
                    || bound.pattern.is(WildcardPatternSyntax.self)
            }
            return false
        }

        static func namesSomebodyElsesCases(_ node: SwitchCaseSyntax) -> Bool {
            node.attribute?.attributeName.trimmedDescription == ChoiceRules.theirs
        }

        static func patterns(of node: SwitchCaseSyntax) -> [PatternSyntax] {
            guard let label = node.label.as(SwitchCaseLabelSyntax.self) else { return [] }
            return label.caseItems.map(\.pattern)
        }
    }
}
