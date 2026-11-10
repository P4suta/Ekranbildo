import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability

public struct StitchError: Error, CustomStringConvertible, Sendable {
    public let code: DiagnosticCode
    public let detail: String

    public var description: String { "\(code): \(detail)" }

    public static let nothingToJoin: DiagnosticCode = 600
    public static let mismatchedFrames: DiagnosticCode = 601
}

public struct FrameShift: Hashable, Sendable {
    public let rows: Int
    public let confidence: Double
}

public struct UncertainJoin: Hashable, Sendable {
    public let betweenFrames: Int
    public let atRow: Int
    public let confidence: Double
}

public struct StitchResult: Sendable {
    public let image: ImageBuffer
    public let stickyTop: Int
    public let stickyBottom: Int
    public let uncertainJoins: [UncertainJoin]
    public let rowComparisons: Int
}

public struct Stitcher: Sendable {
    let minimumOverlap: Int
    private let acceptableCorrelation: Double

    public init(
        minimumOverlap: Int = Defaults.minimumOverlap,
        acceptableCorrelation: Double = Defaults.acceptableCorrelation
    ) {
        self.minimumOverlap = max(1, minimumOverlap)
        self.acceptableCorrelation = acceptableCorrelation
    }

    public enum Defaults {
        public static let minimumOverlap = 24

        public static let acceptableCorrelation = 0.9

        public static let stillnessTolerance = 3
    }

    public func shift(from first: ImageBuffer, to second: ImageBuffer) -> FrameShift? {
        shift(from: first, to: second, ignoringRows: [], comparisons: nil)
    }

    func shift(
        from first: ImageBuffer,
        to second: ImageBuffer,
        ignoringRows ignored: Set<Int>,
        comparisons: UnsafeMutablePointer<Int>?
    ) -> FrameShift? {
        let height = min(first.height, second.height)
        guard height > 0, first.width > 0 else { return nil }

        let column = first.width / Columns.divisor
        let left = Self.strip(of: first, column: column)
        let right = Self.strip(of: second, column: column)

        var best: FrameShift?
        for candidate in -(height - minimumOverlap)...(height - minimumOverlap) {
            let overlap = height - abs(candidate)
            guard overlap >= minimumOverlap else { continue }

            let firstStart = candidate >= 0 ? candidate : 0
            let secondStart = candidate >= 0 ? 0 : -candidate
            let matched = Self.correlation(
                Window(values: left, start: firstStart),
                Window(values: right, start: secondStart),
                length: overlap,
                ignoring: ignored
            )
            comparisons?.pointee += overlap

            guard matched.rows >= minimumOverlap else { continue }
            let score = matched.score

            guard let current = best else {
                best = FrameShift(rows: candidate, confidence: score)
                continue
            }
            if score > current.confidence
                || (score == current.confidence
                    && (abs(candidate) < abs(current.rows)
                        || (abs(candidate) == abs(current.rows) && candidate < current.rows)))
            {
                best = FrameShift(rows: candidate, confidence: score)
            }
        }

        guard let best, best.confidence >= acceptableCorrelation else { return nil }
        return best
    }

    static func strip(of image: ImageBuffer, column: Int) -> [Double] {
        (0..<image.height).map { image[x: column, y: $0].luminance }
    }

    struct Window {
        let values: [Double]
        let start: Int
    }

    static func correlation(
        _ first: Window,
        _ second: Window,
        length: Int,
        ignoring: Set<Int>
    ) -> Overlap {
        let firstStart = first.start
        let secondStart = second.start
        let firstValues = first.values
        let secondValues = second.values
        guard length > 0 else { return Overlap(score: 0, rows: 0) }

        func comparable(_ index: Int) -> Bool {
            !ignoring.contains(firstStart + index) && !ignoring.contains(secondStart + index)
        }

        var firstSum = DeterministicSum()
        var secondSum = DeterministicSum()
        var used = 0
        for index in 0..<length where comparable(index) {
            firstSum.add(firstValues[firstStart + index])
            secondSum.add(secondValues[secondStart + index])
            used += 1
        }
        guard used > 0 else { return Overlap(score: 0, rows: 0) }

        let firstMean = firstSum.value() / Double(used)
        let secondMean = secondSum.value() / Double(used)

        var covariance = DeterministicSum()
        var firstVariance = DeterministicSum()
        var secondVariance = DeterministicSum()
        for index in 0..<length where comparable(index) {
            let a = firstValues[firstStart + index] - firstMean
            let b = secondValues[secondStart + index] - secondMean
            covariance.add(a * b)
            firstVariance.add(a * a)
            secondVariance.add(b * b)
        }

        let spread = (firstVariance.value() * secondVariance.value()).squareRoot()
        guard spread > Tolerance.geometric else {
            return Overlap(score: 1, rows: used)
        }
        return Overlap(score: max(0, min(1, covariance.value() / spread)), rows: used)
    }

    private enum Columns {
        static let divisor = 2
    }
}
