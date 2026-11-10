import EkranbildoContracts

public struct RegionDetector: Sendable {
    private let image: ImageBuffer
    private let localTolerance: Double
    private let globalTolerance: Double
    private let maximumVisited: Int

    public init(
        image: ImageBuffer,
        localTolerance: Double = Defaults.localTolerance,
        globalTolerance: Double = Defaults.globalTolerance,
        maximumVisited: Int = Defaults.maximumVisited
    ) {
        self.image = image
        self.localTolerance = localTolerance
        self.globalTolerance = globalTolerance
        self.maximumVisited = maximumVisited
    }

    public enum Defaults {
        public static let localTolerance: Double = 0.012

        public static let globalTolerance: Double = 0.16

        public static let maximumVisited = 4_000_000
    }

    public func region(containing point: ScenePoint) -> SceneRect? {
        guard !image.isEmpty, image.isWellFormed else { return nil }
        let column = Int(point.x.rounded(.down))
        let row = Int(point.y.rounded(.down))
        guard column >= 0, row >= 0, column < image.width, row < image.height else { return nil }

        let seed = image[x: column, y: row]
        var visited = [Bool](repeating: false, count: image.width * image.height)
        var stack = [(column, row)]
        visited[row * image.width + column] = true

        var minX = column
        var maxX = column
        var minY = row
        var maxY = row
        var count = 0

        while let (currentColumn, currentRow) = stack.popLast() {
            count += 1
            if count > maximumVisited { break }

            minX = min(minX, currentColumn)
            maxX = max(maxX, currentColumn)
            minY = min(minY, currentRow)
            maxY = max(maxY, currentRow)

            for (stepColumn, stepRow) in Self.neighbours {
                let nextColumn = currentColumn + stepColumn
                let nextRow = currentRow + stepRow
                guard nextColumn >= 0, nextRow >= 0,
                    nextColumn < image.width, nextRow < image.height
                else { continue }

                let index = nextRow * image.width + nextColumn
                guard !visited[index] else { continue }

                let candidate = image[x: nextColumn, y: nextRow]
                let here = image[x: currentColumn, y: currentRow]
                guard Self.isSimilar(candidate, here, tolerance: localTolerance),
                    Self.isSimilar(candidate, seed, tolerance: globalTolerance)
                else { continue }

                visited[index] = true
                stack.append((nextColumn, nextRow))
            }
        }

        return SceneRect(
            x: Double(minX),
            y: Double(minY),
            width: Double(maxX - minX + 1),
            height: Double(maxY - minY + 1)
        )
    }

    private static let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    static func isSimilar(
        _ first: ImageBuffer.Pixel,
        _ second: ImageBuffer.Pixel,
        tolerance: Double
    ) -> Bool {
        let limit = tolerance * Double(ImageBuffer.Channel.maximum)
        return abs(Double(first.red) - Double(second.red)) <= limit
            && abs(Double(first.green) - Double(second.green)) <= limit
            && abs(Double(first.blue) - Double(second.blue)) <= limit
    }
}
