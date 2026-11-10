import EkranbildoContracts

public struct CombinedSemanticProvider: SemanticProvider {
    private let providers: [any SemanticProvider]

    public init(_ providers: [any SemanticProvider]) {
        self.providers = providers
    }

    public var version: String {
        providers.map(\.version).joined(separator: "+")
    }

    static func withoutTextFragments(_ elements: [ScreenElement]) -> [ScreenElement] {
        let lines = elements.filter { $0.kind == .text }
        guard !lines.isEmpty else { return elements }

        return elements.filter { element in
            guard element.kind != .text else { return true }
            return !lines.contains { $0.rect.raw.contains(element.rect.raw) }
        }
    }

    public func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
        let canvas = SceneRect(
            x: 0, y: 0, width: Double(image.width), height: Double(image.height))
        var elements: [ScreenElement] = []
        var saliency = SaliencyMap.empty

        for provider in providers {
            let answer = try provider.analyse(image)
            elements.append(contentsOf: answer.elements)
            if saliency.isEmpty, !answer.saliency.isEmpty {
                saliency = answer.saliency
            }
        }

        return SceneSemantics(
            canvas: canvas,
            elements: Self.withoutTextFragments(elements).sorted {
                $0.rect.raw.area == $1.rect.raw.area
                    ? ($0.rect.minY, $0.rect.minX, $0.provenance.rawValue)
                        < ($1.rect.minY, $1.rect.minX, $1.provenance.rawValue)
                    : $0.rect.raw.area > $1.rect.raw.area
            },
            saliency: saliency,
            providerVersion: version
        )
    }
}
