import EkranbildoContracts

public struct EdgeMap: Sendable {
    public let width: Int
    public let height: Int
    public let values: [Double]

    private enum Sobel {
        static let horizontal = [
            -1.0, 0.0, 1.0,
            -2.0, 0.0, 2.0,
            -1.0, 0.0, 1.0,
        ]
        static let vertical = [
            -1.0, -2.0, -1.0,
            0.0, 0.0, 0.0,
            1.0, 2.0, 1.0,
        ]
        static let radius = 1
        static let fullContrastEdge = 1.0 + 2.0 + 1.0
    }

    public enum Defaults {
        public static let noiseFloor: Double = 1e-9
    }

    public init(of image: ImageBuffer) {
        width = image.width
        height = image.height
        guard !image.isEmpty, image.isWellFormed else {
            values = []
            return
        }

        var result = [Double](repeating: 0, count: width * height)
        for row in 0..<height {
            for column in 0..<width {
                var horizontal = 0.0
                var vertical = 0.0
                var tap = 0
                for offsetRow in -Sobel.radius...Sobel.radius {
                    for offsetColumn in -Sobel.radius...Sobel.radius {
                        let luminance = image[x: column + offsetColumn, y: row + offsetRow].luminance
                        horizontal += luminance * Sobel.horizontal[tap]
                        vertical += luminance * Sobel.vertical[tap]
                        tap += 1
                    }
                }
                let magnitude = (horizontal * horizontal + vertical * vertical).squareRoot()
                let strength = min(1, magnitude / Sobel.fullContrastEdge)
                result[row * width + column] = strength < Defaults.noiseFloor ? 0 : strength
            }
        }
        values = result
    }

    public subscript(x column: Int, y row: Int) -> Double {
        guard column >= 0, row >= 0, column < width, row < height, !values.isEmpty else { return 0 }
        return values[row * width + column]
    }
}
