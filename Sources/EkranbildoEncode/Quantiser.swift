import EkranbildoContracts

public struct PaletteColor: Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct QuantisedFrames: Hashable, Sendable {
    public let palette: [PaletteColor]
    public let frames: [[UInt8]]
    public let work: Work

    public struct Work: Hashable, Sendable {
        public let pixelsRead: Int
        public let distinctColors: Int
        public let paletteComparisons: Int
    }
}

public struct CountedColour: Hashable, Sendable {
    public let color: PaletteColor
    public let count: Int

    public init(color: PaletteColor, count: Int) {
        self.color = color
        self.count = count
    }
}

public struct Quantiser: Sendable {
    private let colors: Int

    public init(colors: Int = Limits.colors) {
        self.colors = min(Limits.colors, max(1, colors))
    }

    public enum Limits {
        public static let colors = 256
    }

    public func quantise(_ pictures: [ImageBuffer]) -> QuantisedFrames {
        guard !pictures.isEmpty else {
            return QuantisedFrames(
                palette: [],
                frames: [],
                work: QuantisedFrames.Work(
                    pixelsRead: 0,
                    distinctColors: 0,
                    paletteComparisons: 0
                )
            )
        }

        let pixels = pictures.reduce(0) { $0 + $1.width * $1.height }
        var counts = [Int32](repeating: 0, count: Histogram.size)
        let distinct = Self.distinctColors(in: pictures, counting: &counts)

        guard !distinct.isEmpty else {
            return QuantisedFrames(
                palette: [PaletteColor(red: 0, green: 0, blue: 0)],
                frames: pictures.map { _ in [] },
                work: QuantisedFrames.Work(
                    pixelsRead: pixels, distinctColors: 0, paletteComparisons: 0)
            )
        }

        let palette = Self.medianCut(distinct, into: colors)

        var mapping = [UInt8](repeating: 0, count: Histogram.size)
        for entry in distinct {
            mapping[Self.key(entry.color.red, entry.color.green, entry.color.blue)] =
                Self.nearest(to: entry.color, in: palette)
        }

        return QuantisedFrames(
            palette: palette,
            frames: pictures.map { picture in
                var indices = [UInt8](repeating: 0, count: picture.width * picture.height)
                for row in 0..<picture.height {
                    for column in 0..<picture.width {
                        let pixel = picture[x: column, y: row]
                        indices[row * picture.width + column] =
                            mapping[Self.key(pixel.red, pixel.green, pixel.blue)]
                    }
                }
                return indices
            },
            work: QuantisedFrames.Work(
                pixelsRead: pixels * Passes.overEveryPixel,
                distinctColors: distinct.count,
                paletteComparisons: distinct.count * palette.count
            )
        )
    }

    private enum Split {
        static let halves = 2
    }

    private enum Histogram {
        static let size = 1 << (Channel.bits * Channel.count)
    }

    private enum Passes {
        static let overEveryPixel = 2
    }

    static func distinctColors(
        in pictures: [ImageBuffer],
        counting counts: inout [Int32]
    ) -> [CountedColour] {
        for picture in pictures {
            for row in 0..<picture.height {
                for column in 0..<picture.width {
                    let pixel = picture[x: column, y: row]
                    counts[key(pixel.red, pixel.green, pixel.blue)] += 1
                }
            }
        }

        var found: [CountedColour] = []
        for slot in 0..<counts.count where counts[slot] > 0 {
            found.append(
                CountedColour(
                    color: PaletteColor(
                        red: UInt8((slot >> Channel.redShift) & Channel.mask),
                        green: UInt8((slot >> Channel.greenShift) & Channel.mask),
                        blue: UInt8(slot & Channel.mask)
                    ),
                    count: Int(counts[slot])
                ))
        }
        return found
    }

    static func key(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> Int {
        (Int(red) << Channel.redShift) | (Int(green) << Channel.greenShift) | Int(blue)
    }

    enum Channel {
        static let mask = 0xFF
        static let bits = 8
        static let count = 3
        static let greenShift = bits
        static let redShift = bits * redPlaces
        private static let redPlaces = 2
    }

    static func medianCut(
        _ colors: [CountedColour],
        into limit: Int
    ) -> [PaletteColor] {
        var boxes = [colors]

        while boxes.count < limit {
            var best = -1
            var bestScore = 0
            for (index, box) in boxes.enumerated() {
                let score = weight(box) * spread(box)
                if score > bestScore, box.count > 1 {
                    bestScore = score
                    best = index
                }
            }
            guard best >= 0 else { break }

            let box = boxes[best]
            let axis = widestAxis(box)
            let sorted = box.sorted {
                component($0.color, axis) == component($1.color, axis)
                    ? key($0.color.red, $0.color.green, $0.color.blue)
                        < key($1.color.red, $1.color.green, $1.color.blue)
                    : component($0.color, axis) < component($1.color, axis)
            }

            let cut = max(1, min(sorted.count - 1, sorted.count / Split.halves))

            boxes.remove(at: best)
            boxes.insert(contentsOf: [Array(sorted[..<cut]), Array(sorted[cut...])], at: best)
        }

        return boxes.map(average)
    }

    static func average(_ box: [CountedColour]) -> PaletteColor {
        let total = weight(box)
        guard total > 0 else { return PaletteColor(red: 0, green: 0, blue: 0) }

        var red = 0
        var green = 0
        var blue = 0
        for entry in box {
            red += Int(entry.color.red) * entry.count
            green += Int(entry.color.green) * entry.count
            blue += Int(entry.color.blue) * entry.count
        }
        let half = total / Split.halves
        return PaletteColor(
            red: UInt8((red + half) / total),
            green: UInt8((green + half) / total),
            blue: UInt8((blue + half) / total)
        )
    }

    static func weight(_ box: [CountedColour]) -> Int {
        box.reduce(0) { $0 + $1.count }
    }

    static func spread(_ box: [CountedColour]) -> Int {
        let axis = widestAxis(box)
        let values = box.map { component($0.color, axis) }
        guard let low = values.min(), let high = values.max() else { return 0 }
        return high - low
    }

    static func widestAxis(_ box: [CountedColour]) -> Axis {
        var widest = Axis.red
        var widestRange = -1
        for axis in Axis.allCases {
            let values = box.map { component($0.color, axis) }
            let range = (values.max() ?? 0) - (values.min() ?? 0)
            if range > widestRange {
                widestRange = range
                widest = axis
            }
        }
        return widest
    }

    enum Axis: CaseIterable {
        case red, green, blue
    }

    static func component(_ color: PaletteColor, _ axis: Axis) -> Int {
        switch axis {
        case .red: Int(color.red)
        case .green: Int(color.green)
        case .blue: Int(color.blue)
        }
    }

    static func nearest(to color: PaletteColor, in palette: [PaletteColor]) -> UInt8 {
        var best = 0
        var bestDistance = Int.max
        for (index, candidate) in palette.enumerated() {
            let red = Int(color.red) - Int(candidate.red)
            let green = Int(color.green) - Int(candidate.green)
            let blue = Int(color.blue) - Int(candidate.blue)
            let distance = red * red + green * green + blue * blue
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return UInt8(best)
    }
}
