import EkranbildoGeometry
import EkranbildoObservability

public struct NormalizedBox: Hashable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func inScene(of size: Size) -> SceneRect {
        SceneRect(
            x: x * size.width,
            y: (1 - (y + height)) * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}

public struct SaliencyMap: Hashable, Sendable, Codable {
    public let columns: Int
    public let rows: Int
    public let values: [Double]

    public init(columns: Int, rows: Int, values: [Double]) {
        self.columns = columns
        self.rows = rows
        self.values = values
    }

    public static let empty = Self(columns: 0, rows: 0, values: [])

    public var isEmpty: Bool { columns <= 0 || rows <= 0 || values.isEmpty }

    public var isWellFormed: Bool { !isEmpty && values.count == columns * rows }

    private enum CodingKeys: String, CodingKey {
        case columns
        case rows
        case rowValues
    }

    private enum Encoding {
        static let places = 3
        static let separator: Character = " "
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        columns = try container.decode(Int.self, forKey: .columns)
        rows = try container.decode(Int.self, forKey: .rows)
        values = try container.decode([String].self, forKey: .rowValues)
            .flatMap { line in
                line.split(separator: Encoding.separator).map { Double($0) ?? 0 }
            }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(rows, forKey: .rows)

        var lines: [String] = []
        if isWellFormed {
            lines.reserveCapacity(rows)
            for row in 0..<rows {
                let start = row * columns
                lines.append(
                    values[start..<(start + columns)]
                        .map { CanonicalText.rounded($0, places: Encoding.places) }
                        .joined(separator: String(Encoding.separator))
                )
            }
        }
        try container.encode(lines, forKey: .rowValues)
    }

    public subscript(column column: Int, row row: Int) -> Double {
        guard isWellFormed, column >= 0, row >= 0, column < columns, row < rows else { return 0 }
        return values[row * columns + column]
    }

    public func value(at point: ScenePoint, in canvas: SceneRect) -> Double {
        guard isWellFormed, canvas.raw.width > 0, canvas.raw.height > 0,
            canvas.raw.contains(point.raw)
        else { return 0 }

        let acrossCanvas = (point.x - canvas.minX) / canvas.raw.width
        let downCanvas = (point.y - canvas.minY) / canvas.raw.height
        let column = min(columns - 1, Int(acrossCanvas * Double(columns)))
        let row = min(rows - 1, Int(downCanvas * Double(rows)))
        return self[column: column, row: row]
    }
}

public struct SceneSemantics: Hashable, Sendable, Codable {
    public let canvas: SceneRect
    public let elements: [ScreenElement]
    public let saliency: SaliencyMap
    public let providerVersion: String

    public init(
        canvas: SceneRect,
        elements: [ScreenElement],
        saliency: SaliencyMap,
        providerVersion: String
    ) {
        self.canvas = canvas
        self.elements = elements
        self.saliency = saliency
        self.providerVersion = providerVersion
    }

    public static func empty(canvas: SceneRect, providerVersion: String) -> Self {
        Self(canvas: canvas, elements: [], saliency: .empty, providerVersion: providerVersion)
    }
}

public protocol SemanticProvider: Sendable {
    var version: String { get }

    func analyse(_ image: ImageBuffer) throws -> SceneSemantics
}

public struct SemanticsError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public init(code: DiagnosticCode, detail: String) {
        self.code = code
        self.detail = detail
    }

    public static let snapshotMismatch: DiagnosticCode = 400
    public static let recognitionFailed: DiagnosticCode = 401
}
