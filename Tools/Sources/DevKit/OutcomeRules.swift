import Foundation
import SwiftParser
import SwiftSyntax

public enum OutcomeRules {
    public static func findings(in source: String, path: String) -> [Finding] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let walker = Walker(path: path, locations: locations)
        walker.walk(tree)
        return walker.found.sorted { $0.line < $1.line }
    }

    static let permission = "discardableResult"

    static let outcomes: Set<String> = ["Bool", "Result"]

    static let advice =
        "This says a caller may drop what it returns, and what it returns is whether it "
        + "worked. A dropped failure reads exactly like a success at every call site. "
        + "Either act on it, or return something that cannot be mistaken for a result."

    private final class Walker: SyntaxVisitor {
        let path: String
        let locations: SourceLocationConverter
        var found: [Finding] = []

        init(path: String, locations: SourceLocationConverter) {
            self.path = path
            self.locations = locations
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
            guard Self.mayBeDropped(node.attributes),
                let returned = node.signature.returnClause?.type,
                OutcomeRules.reportsSuccess(returned)
            else { return .visitChildren }
            let line = locations.location(
                for: node.positionAfterSkippingLeadingTrivia
            ).line
            found.append(Finding(path: path, line: line, advice: OutcomeRules.advice))
            return .visitChildren
        }

        static func mayBeDropped(_ attributes: AttributeListSyntax) -> Bool {
            attributes.contains {
                $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription
                    == OutcomeRules.permission
            }
        }
    }

    static func reportsSuccess(_ type: TypeSyntax) -> Bool {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return reportsSuccess(optional.wrappedType)
        }
        let named = type.as(IdentifierTypeSyntax.self)?.name.text
        return named.map(outcomes.contains) ?? false
    }
}
