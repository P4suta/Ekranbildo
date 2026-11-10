import EkranbildoContracts
import EkranbildoGeometry

public struct TargetSnapper: Sendable {
    private let detector: ElementDetector

    public init(detector: ElementDetector = ElementDetector()) {
        self.detector = detector
    }

    public func targets(in image: ImageBuffer, at point: ScenePoint) -> [SceneRect] {
        targets(among: detector.detect(in: image), at: point)
    }

    static func smallestFirst(_ first: SceneRect, _ second: SceneRect) -> Bool {
        if first.raw.area != second.raw.area {
            return first.raw.area < second.raw.area
        }
        if first.minY != second.minY {
            return first.minY < second.minY
        }
        return first.minX < second.minX
    }

    public func targets(among elements: [ScreenElement], at point: ScenePoint) -> [SceneRect] {
        let under = elements.map(\.rect).filter { $0.raw.contains(point.raw) }
        let containing = under.sorted(by: Self.smallestFirst)

        var ladder: [SceneRect] = []
        for rect in containing {
            guard let previous = ladder.last else {
                ladder.append(rect)
                continue
            }
            guard rect.raw.area >= previous.raw.area * Defaults.minimumWidening,
                rect.raw.contains(previous.raw)
            else { continue }
            ladder.append(rect)
        }
        return ladder
    }

    public static func target(at index: Int, among ladder: [SceneRect]) -> SceneRect? {
        guard !ladder.isEmpty else { return nil }
        let count = ladder.count
        return ladder[((index % count) + count) % count]
    }

    public enum Defaults {
        public static let minimumWidening: Double = 1.2
    }
}
