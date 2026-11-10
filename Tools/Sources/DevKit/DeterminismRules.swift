import Foundation
import SwiftParser
import SwiftSyntax


public struct Finding: Sendable, Equatable {
    public let path: String
    public let line: Int
    public let advice: String

    public init(path: String, line: Int, advice: String) {
        self.path = path
        self.line = line
        self.advice = advice
    }
}

public enum DeterminismRules {
    public static func findings(in source: String, path: String) -> [Finding] {
        let tree = Parser.parse(source: source)
        let locations = SourceLocationConverter(fileName: path, tree: tree)
        let visitor = Walker(path: path, locations: locations, source: source)
        visitor.walk(tree)
        return visitor.found.sorted { $0.line < $1.line }
    }

    static let keyedStoreLives = "EkranbildoGeometry/Lookup.swift"

    static func mayHoldAKeyedStore(_ path: String) -> Bool {
        path == keyedStoreLives || path.hasSuffix("/" + keyedStoreLives)
    }

    static let marker = "determinism:allow"
    static let nextMarker = "determinism:allow:next"

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

        override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            note(node.baseName.text, at: Syntax(node))
            return .visitChildren
        }

        override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            note(node.name.text, at: Syntax(node))
            return .visitChildren
        }

        override func visit(_ node: DictionaryTypeSyntax) -> SyntaxVisitorContinueKind {
            if !DeterminismRules.mayHoldAKeyedStore(path) {
                record(Advice.unordered, at: Syntax(node))
            }
            return .visitChildren
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
                return .visitChildren
            }
            guard let advice = Advice.random[member.declName.baseName.text] else {
                return .visitChildren
            }
            let seeded = node.arguments.contains { $0.label?.text == "using" }
            if !seeded { record(advice, at: Syntax(node)) }
            return .visitChildren
        }

        private func note(_ name: String, at node: Syntax) {
            guard let advice = Advice.names[name] else { return }
            if advice == Advice.unordered, DeterminismRules.mayHoldAKeyedStore(path) { return }
            record(advice, at: node)
        }

        private func record(_ advice: String, at node: Syntax) {
            let line = locations.location(for: node.positionAfterSkippingLeadingTrivia).line
            guard !isExcused(line) else { return }
            guard !found.contains(where: { $0.line == line && $0.advice == advice }) else { return }
            found.append(Finding(path: path, line: line, advice: advice))
        }

        private func isExcused(_ line: Int) -> Bool {
            if reason(on: line, marker: DeterminismRules.marker) != nil { return true }

            var above = line - 1
            while above >= 1, isAllComment(above) {
                if reason(on: above, marker: DeterminismRules.nextMarker) != nil { return true }
                above -= 1
            }
            return false
        }

        private func isAllComment(_ line: Int) -> Bool {
            guard line >= 1, line <= lines.count else { return false }
            return lines[line - 1].trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }

        private func reason(on line: Int, marker: String) -> String? {
            guard line >= 1, line <= lines.count else { return nil }
            guard let found = lines[line - 1].range(of: marker) else { return nil }
            if marker == DeterminismRules.marker,
                lines[line - 1].contains(DeterminismRules.nextMarker)
            {
                return nil
            }
            let rest = lines[line - 1][found.upperBound...]
                .trimmingCharacters(in: .whitespaces)
            return rest.isEmpty ? nil : rest
        }
    }

    private enum Advice {
        static let unordered =
            "Dictionary and Set iterate in an order that varies between processes. Hold an "
            + "array, or sort the keys at use and say so."

        static let names: [String: String] = [
            "UUID": "UUID() is nondeterministic; use StableID and an allocator.",
            "Date": "Reading the wall clock is nondeterministic; inject a Clocking capability.",
            "Locale": "Ambient locale makes output machine-dependent; inject it.",
            "TimeZone": "Ambient time zone makes output machine-dependent; inject it.",
            "Calendar": "Ambient calendar makes output machine-dependent; inject it.",
            "SystemRandomNumberGenerator": "Use SplitMix64 with an explicit seed.",
            "Float80": "Use Double everywhere; other widths differ in precision across platforms.",
            "Float16": "Use Double everywhere; other widths differ in precision across platforms.",
            "ObjectIdentifier": "ObjectIdentifier ordering depends on memory addresses.",
            "Set": unordered,
            "Dictionary": unordered,
        ]

        static let random: [String: String] = [
            "shuffled": "Randomness without an explicit generator uses the system RNG; pass a SplitMix64.",
            "shuffle": "Randomness without an explicit generator uses the system RNG; pass a SplitMix64.",
            "randomElement":
                "Randomness without an explicit generator uses the system RNG; pass a SplitMix64.",
            "random": "Randomness without an explicit generator uses the system RNG; pass a SplitMix64.",
        ]
    }
}

extension DeterminismRules {
    public static func scan(_ directories: [URL]) throws -> [Finding] {
        var found: [Finding] = []
        for directory in directories {
            for file in try swiftFiles(in: directory) {
                let source = try String(contentsOf: file, encoding: .utf8)
                let relative = file.path.replacingOccurrences(
                    of: directory.deletingLastPathComponent().path + "/", with: "")
                found += findings(in: source, path: relative)
            }
        }
        return found.sorted { ($0.path, $0.line) < ($1.path, $1.line) }
    }

    static func swiftFiles(in directory: URL) throws -> [URL] {
        guard
            let walker = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        var files: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            files.append(url)
        }
        return files.sorted { $0.path < $1.path }
    }
}
