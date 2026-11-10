import EkranbildoContracts

public struct RegionSemanticProvider: SemanticProvider {
    private let detector: ElementDetector

    public init(detector: ElementDetector = ElementDetector()) {
        self.detector = detector
    }

    public var version: String { "region-1" }

    public func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
        SceneSemantics(
            canvas: SceneRect(x: 0, y: 0, width: Double(image.width), height: Double(image.height)),
            elements: detector.detect(in: image),
            saliency: .empty,
            providerVersion: version
        )
    }
}
