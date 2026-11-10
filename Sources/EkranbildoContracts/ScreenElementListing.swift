import EkranbildoObservability

extension ScreenElement {

    public var canonicalText: String {
        ([
            kind.rawValue,
            rect.canonicalText,
            CanonicalText.rounded(confidence, places: Precision.places),
            provenance.rawValue,
        ] + (text.map { ["\"\($0)\""] } ?? []))
        .joined(separator: " ")
    }

    public static func listing(_ elements: [Self]) -> String {
        elements.enumerated()
            .map { "\($0.offset) \($0.element.canonicalText)" }
            .joined(separator: "\n")
    }

    private enum Precision {
        static let places = 2
    }
}
