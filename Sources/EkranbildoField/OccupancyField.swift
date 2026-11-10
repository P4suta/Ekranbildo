import EkranbildoContracts
import EkranbildoGeometry

public enum FieldLayer: String, CaseIterable, Sendable, Codable {
    case elements
    case textInk
    case edgeEnergy
    case saliency
    case borderMargin
    case placedAnnotations
}

public struct OccupancyFieldBuilder: Sendable {
    private let canvas: SceneRect
    private let cellSize: Double
    private let columns: Int
    private let rows: Int
    private var planes: [[Double]]

    public enum Defaults {
        public static let cellSize: Double = 8

        static let smallestUsefulCell: Double = 1e-6

        public static let corridorSamples = 32
    }

    public init(canvas: SceneRect, cellSize: Double = Defaults.cellSize) {
        self.canvas = canvas
        self.cellSize = max(cellSize, Defaults.smallestUsefulCell)
        columns = max(1, Int((canvas.width / self.cellSize).rounded(.up)))
        rows = max(1, Int((canvas.height / self.cellSize).rounded(.up)))
        planes = Array(
            repeating: [Double](repeating: 0, count: columns * rows),
            count: FieldLayer.allCases.count
        )
    }

    public mutating func add(_ rect: SceneRect, weight: Double, to layer: FieldLayer) {
        guard weight > 0, rect.width > 0, rect.height > 0 else { return }

        let minColumn = max(0, Int(((rect.minX - canvas.minX) / cellSize).rounded(.down)))
        let maxColumn = min(columns - 1, Int(((rect.maxX - canvas.minX) / cellSize).rounded(.up)) - 1)
        let minRow = max(0, Int(((rect.minY - canvas.minY) / cellSize).rounded(.down)))
        let maxRow = min(rows - 1, Int(((rect.maxY - canvas.minY) / cellSize).rounded(.up)) - 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return }

        let plane = layer.planeIndex
        let cellArea = cellSize * cellSize
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let cell = cellRect(column: column, row: row)
                let covered = Geo.overlapArea(cell.raw, rect.raw)
                guard covered > 0 else { continue }
                let index = row * columns + column
                let added = planes[plane][index] + weight * (covered / cellArea)
                planes[plane][index] = min(1, added)
            }
        }
    }

    private func cellRect(column: Int, row: Int) -> SceneRect {
        SceneRect(
            x: canvas.minX + Double(column) * cellSize,
            y: canvas.minY + Double(row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    public func build() -> OccupancyField {
        var composite = [Double](repeating: 0, count: columns * rows)
        for index in composite.indices {
            var total = DeterministicSum()
            for plane in planes.indices {
                total.add(planes[plane][index])
            }
            composite[index] = min(1, total.value())
        }
        return OccupancyField(
            canvas: canvas,
            cellSize: cellSize,
            columns: columns,
            rows: rows,
            planes: planes,
            cells: composite
        )
    }
}

public struct OccupancyField: Sendable {
    public let canvas: SceneRect
    public let cellSize: Double
    public let columns: Int
    public let rows: Int
    public let cells: [Double]

    private let planes: [[Double]]
    private let compositeTable: [Double]
    private let planeTables: [[Double]]

    public static let outOfBoundsCost: Double = 1

    public var corridorSampleCount: Int { OccupancyFieldBuilder.Defaults.corridorSamples }

    init(
        canvas: SceneRect,
        cellSize: Double,
        columns: Int,
        rows: Int,
        planes: [[Double]],
        cells: [Double]
    ) {
        self.canvas = canvas
        self.cellSize = cellSize
        self.columns = columns
        self.rows = rows
        self.planes = planes
        self.cells = cells
        compositeTable = Self.summedAreaTable(cells, columns: columns, rows: rows)
        planeTables = planes.map { Self.summedAreaTable($0, columns: columns, rows: rows) }
    }

    private static func summedAreaTable(_ source: [Double], columns: Int, rows: Int) -> [Double] {
        let stride = columns + 1
        var table = [Double](repeating: 0, count: stride * (rows + 1))
        for row in 0..<rows {
            for column in 0..<columns {
                let value = source[row * columns + column]
                table[(row + 1) * stride + column + 1] =
                    value
                    + table[row * stride + column + 1]
                    + table[(row + 1) * stride + column]
                    - table[row * stride + column]
            }
        }
        return table
    }

    public func meanCost(in rect: SceneRect) -> Double {
        meanCost(in: rect, table: compositeTable)
    }

    public func meanCost(in rect: SceneRect, layer: FieldLayer) -> Double {
        meanCost(in: rect, table: planeTables[layer.planeIndex])
    }

    public func plane(_ layer: FieldLayer) -> [Double] {
        planes[layer.planeIndex]
    }

    private func meanCost(in rect: SceneRect, table: [Double]) -> Double {
        let area = rect.width * rect.height
        guard area > 0 else { return 0 }

        let inside = intersection(rect, canvas)
        let insideArea = inside.map { $0.width * $0.height } ?? 0
        let outsideFraction = max(0, (area - insideArea) / area)

        guard let inside, insideArea > 0 else { return Self.outOfBoundsCost }

        let minColumn = max(0, Int(((inside.minX - canvas.minX) / cellSize).rounded(.down)))
        let maxColumn = min(columns - 1, Int(((inside.maxX - canvas.minX) / cellSize).rounded(.up)) - 1)
        let minRow = max(0, Int(((inside.minY - canvas.minY) / cellSize).rounded(.down)))
        let maxRow = min(rows - 1, Int(((inside.maxY - canvas.minY) / cellSize).rounded(.up)) - 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return Self.outOfBoundsCost }

        let stride = columns + 1
        let total =
            table[(maxRow + 1) * stride + maxColumn + 1]
            - table[minRow * stride + maxColumn + 1]
            - table[(maxRow + 1) * stride + minColumn]
            + table[minRow * stride + minColumn]
        let count = Double((maxRow - minRow + 1) * (maxColumn - minColumn + 1))
        let insideCost = total / count

        return insideCost * (1 - outsideFraction) + Self.outOfBoundsCost * outsideFraction
    }

    private func intersection(_ a: SceneRect, _ b: SceneRect) -> SceneRect? {
        let minX = max(a.minX, b.minX)
        let minY = max(a.minY, b.minY)
        let maxX = min(a.maxX, b.maxX)
        let maxY = min(a.maxY, b.maxY)
        guard maxX > minX, maxY > minY else { return nil }
        return SceneRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func corridorCost(_ polyline: Polyline, halfWidth: Double) -> Double {
        let samples = corridorSamplePoints(of: polyline)
        guard !samples.isEmpty else { return 0 }

        var total = DeterministicSum()
        for point in samples {
            let probe = SceneRect(
                x: point.x - halfWidth,
                y: point.y - halfWidth,
                width: halfWidth + halfWidth,
                height: halfWidth + halfWidth
            )
            total.add(meanCost(in: probe))
        }
        return total.value() / Double(samples.count)
    }

    public func samplesTaken(for polyline: Polyline) -> Int {
        corridorSamplePoints(of: polyline).count
    }

    public func corridorSamplePoints(of polyline: Polyline) -> [P2] {
        let segments = polyline.segments
        guard !segments.isEmpty else { return [] }

        var lengths: [Double] = []
        var total = DeterministicSum()
        for segment in segments {
            let length = segment.lengthSquared.squareRoot()
            lengths.append(length)
            total.add(length)
        }
        let totalLength = total.value()
        guard totalLength > 0 else { return [] }

        var points: [P2] = []
        points.reserveCapacity(corridorSampleCount)
        for step in 0..<corridorSampleCount {
            let stepCentre = 0.5
            let along = totalLength * (Double(step) + stepCentre) / Double(corridorSampleCount)
            points.append(pointAt(distance: along, segments: segments, lengths: lengths))
        }
        return points
    }

    private func pointAt(distance: Double, segments: [Segment], lengths: [Double]) -> P2 {
        var remaining = distance
        for (index, segment) in segments.enumerated() {
            let length = lengths[index]
            if remaining <= length || index == segments.count - 1 {
                let fraction = length > 0 ? min(1, remaining / length) : 0
                let delta = segment.delta
                return P2(x: segment.a.x + delta.x * fraction, y: segment.a.y + delta.y * fraction)
            }
            remaining -= length
        }
        return segments[segments.count - 1].b
    }
}

extension FieldLayer {
    var planeIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

extension OccupancyField {
    func slowMeanCost(in rect: SceneRect) -> Double {
        let area = rect.width * rect.height
        guard area > 0 else { return 0 }

        let minX = max(rect.minX, canvas.minX)
        let minY = max(rect.minY, canvas.minY)
        let maxX = min(rect.maxX, canvas.maxX)
        let maxY = min(rect.maxY, canvas.maxY)
        guard maxX > minX, maxY > minY else { return Self.outOfBoundsCost }

        let insideArea = (maxX - minX) * (maxY - minY)
        let outsideFraction = max(0, (area - insideArea) / area)

        let minColumn = max(0, Int(((minX - canvas.minX) / cellSize).rounded(.down)))
        let maxColumn = min(columns - 1, Int(((maxX - canvas.minX) / cellSize).rounded(.up)) - 1)
        let minRow = max(0, Int(((minY - canvas.minY) / cellSize).rounded(.down)))
        let maxRow = min(rows - 1, Int(((maxY - canvas.minY) / cellSize).rounded(.up)) - 1)
        guard minColumn <= maxColumn, minRow <= maxRow else { return Self.outOfBoundsCost }

        var total = DeterministicSum()
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                total.add(cells[row * columns + column])
            }
        }
        let count = Double((maxRow - minRow + 1) * (maxColumn - minColumn + 1))
        return total.value() / count * (1 - outsideFraction) + Self.outOfBoundsCost * outsideFraction
    }
}
