import Foundation
import SwiftParser
import SwiftSyntax


public struct Import: Sendable, Equatable {
    public let module: String
    public let line: Int

    public init(module: String, line: Int) {
        self.module = module
        self.line = line
    }
}

public enum ImportRules {
    public static func imports(in source: String) -> [Import] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: "", tree: tree)
        let walker = Walker(locations: locations)
        walker.walk(tree)
        return walker.found
    }

    public static func forbidden(imports: [Import], in module: String) -> [Finding] {
        imports.compactMap { reached in
            guard let reason = why(module, mayNotReach: reached.module) else { return nil }
            return Finding(path: module, line: reached.line, advice: reason)
        }
    }

    static func why(_ module: String, mayNotReach reached: String) -> String? {
        if module == Pure.module, reached == Pure.forbidden {
            return "\(module) is pure Swift by design and must not import \(reached)."
        }
        guard portableModules.contains(module), interfaceFrameworks.contains(reached) else {
            return nil
        }
        return "\(module) must not import \(reached): the layout has to be decided the same "
            + "way for a screenshot that arrived from somewhere else."
    }

    static let portableModules: Set<String> = [
        "EkranbildoGeometry", "EkranbildoObservability", "EkranbildoContracts", "EkranbildoCore",
        "EkranbildoField", "EkranbildoLayout", "EkranbildoRender", "EkranbildoTimeline", "EkranbildoEditor",
    ]

    static let interfaceFrameworks: Set<String> = [
        "AppKit", "UIKit", "SwiftUI", "CoreGraphics", "CoreImage", "QuartzCore",
        "Vision", "ScreenCaptureKit", "AVFoundation", "ImageIO", "CoreText",
    ]

    private enum Pure {
        static let module = "EkranbildoGeometry"
        static let forbidden = "Foundation"
    }

    private final class Walker: SyntaxVisitor {
        let locations: SourceLocationConverter
        var found: [Import] = []

        init(locations: SourceLocationConverter) {
            self.locations = locations
            super.init(viewMode: .sourceAccurate)
        }

        override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
            guard let first = node.path.first?.name.text else { return .skipChildren }
            let line = locations.location(for: node.positionAfterSkippingLeadingTrivia).line
            found.append(Import(module: first, line: line))
            return .skipChildren
        }
    }
}
