import EkranbildoContracts
import EkranbildoGeometry

public struct ElementDetector: Sendable {
    private let localTolerance: Double
    private let globalTolerance: Double
    private let minimumSide: Double
    private let step: Int

    public init(
        localTolerance: Double = RegionDetector.Defaults.localTolerance,
        globalTolerance: Double = RegionDetector.Defaults.globalTolerance,
        minimumSide: Double = Defaults.minimumSide,
        step: Int = Defaults.sweepStep
    ) {
        self.localTolerance = localTolerance
        self.globalTolerance = globalTolerance
        self.minimumSide = minimumSide
        self.step = step
    }

    public enum Defaults {
        public static let minimumSide: Double = 8

        public static let sweepStep = 4

        public static let rectangularFillRatio: Double = 0.8
    }

    public func detect(in image: ImageBuffer) -> [ScreenElement] {
        guard !image.isEmpty, image.isWellFormed else { return [] }

        var claimed = [Bool](repeating: false, count: image.width * image.height)
        var found: [ScreenElement] = []

        var row = 0
        while row < image.height {
            var column = 0
            while column < image.width {
                defer { column += step }
                guard !claimed[row * image.width + column] else { continue }

                guard
                    let region = flood(
                        from: (column, row),
                        in: image,
                        claiming: &claimed
                    )
                else { continue }

                guard min(region.rect.raw.width, region.rect.raw.height) >= minimumSide
                else { continue }
                found.append(
                    ScreenElement(
                        rect: region.rect,
                        kind: .surface,
                        confidence: region.confidence,
                        provenance: .regionAnalysis
                    )
                )
            }
            row += step
        }

        return found.sorted {
            $0.rect.raw.area == $1.rect.raw.area
                ? ($0.rect.minY, $0.rect.minX) < ($1.rect.minY, $1.rect.minX)
                : $0.rect.raw.area > $1.rect.raw.area
        }
    }

    private struct FoundRegion {
        let rect: SceneRect
        let confidence: Double
    }

    private func flood(
        from seed: (column: Int, row: Int),
        in image: ImageBuffer,
        claiming claimed: inout [Bool]
    ) -> FoundRegion? {
        let seedPixel = image[x: seed.column, y: seed.row]
        var stack = [seed]
        claimed[seed.row * image.width + seed.column] = true

        var minX = seed.column
        var maxX = seed.column
        var minY = seed.row
        var maxY = seed.row
        var filled = 0

        while let current = stack.popLast() {
            filled += 1
            minX = min(minX, current.column)
            maxX = max(maxX, current.column)
            minY = min(minY, current.row)
            maxY = max(maxY, current.row)

            for (stepColumn, stepRow) in Self.neighbours {
                let nextColumn = current.column + stepColumn
                let nextRow = current.row + stepRow
                guard nextColumn >= 0, nextRow >= 0,
                    nextColumn < image.width, nextRow < image.height
                else { continue }

                let index = nextRow * image.width + nextColumn
                guard !claimed[index] else { continue }

                let candidate = image[x: nextColumn, y: nextRow]
                let here = image[x: current.column, y: current.row]
                guard RegionDetector.isSimilar(candidate, here, tolerance: localTolerance),
                    RegionDetector.isSimilar(candidate, seedPixel, tolerance: globalTolerance)
                else { continue }

                claimed[index] = true
                stack.append((nextColumn, nextRow))
            }
        }

        let rect = SceneRect(
            x: Double(minX),
            y: Double(minY),
            width: Double(maxX - minX + 1),
            height: Double(maxY - minY + 1)
        )
        let confidence = min(1, Double(filled) / max(1, rect.raw.area))
        return FoundRegion(rect: rect, confidence: confidence)
    }

    private static let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
}
