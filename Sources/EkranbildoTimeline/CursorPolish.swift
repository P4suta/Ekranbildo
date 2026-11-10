import EkranbildoContracts
import EkranbildoGeometry

public struct ClickRipple: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let centre: ScreenPoint

    public init(at: Timestamp, centre: ScreenPoint) {
        self.at = at
        self.centre = centre
    }
}

public struct CursorPolish: Sendable {
    private let window: Int
    private let stillFor: Double
    private let stillWithin: Double
    private let fadedOpacity: Double
    private let smooths: Bool
    private let showsClicks: Bool

    public init(
        window: Int = Defaults.window,
        stillFor: Double = Defaults.stillFor,
        stillWithin: Double = Defaults.stillWithin,
        fadedOpacity: Double = Defaults.fadedOpacity,
        smooths: Bool = Defaults.smooths,
        showsClicks: Bool = Defaults.showsClicks
    ) {
        self.smooths = smooths
        self.showsClicks = showsClicks
        self.window = max(Defaults.smallestWindow, window)
        self.stillFor = max(0, stillFor)
        self.stillWithin = max(0, stillWithin)
        self.fadedOpacity = min(1, max(0, fadedOpacity))
    }

    public enum Defaults {
        public static let window = 2
        public static let smallestWindow = 1
        public static let stillFor: Double = 2
        public static let stillWithin: Double = 3
        public static let fadedOpacity: Double = 0.25
        public static let smooths = true
        public static let showsClicks = true
    }

    public func smooth(_ samples: [CursorSample]) -> [CursorSample] {
        guard smooths else { return samples }
        guard samples.count > window * Span.bothSides else { return samples }

        return samples.enumerated().map { index, sample in
            guard index >= window, index < samples.count - window else { return sample }

            var x = DeterministicSum()
            var y = DeterministicSum()
            for offset in -window...window {
                x.add(samples[index + offset].position.x)
                y.add(samples[index + offset].position.y)
            }
            let count = Double(window * Span.bothSides + 1)

            return CursorSample(
                at: sample.at,
                position: ScreenPoint(x: x.value() / count, y: y.value() / count),
                pressed: sample.pressed
            )
        }
    }

    public func ripples(in samples: [CursorSample]) -> [ClickRipple] {
        guard showsClicks else { return [] }
        var ripples: [ClickRipple] = []
        var wasPressed = false
        for sample in samples {
            if sample.pressed, !wasPressed {
                ripples.append(ClickRipple(at: sample.at, centre: sample.position))
            }
            wasPressed = sample.pressed
        }
        return ripples
    }

    public func opacity(at moment: Timestamp, in samples: [CursorSample]) -> Double {
        guard let current = samples.last(where: { $0.at <= moment }) ?? samples.first else {
            return 0
        }

        var stillSince = current.at
        for sample in samples.reversed() where sample.at <= current.at {
            let moved = Geo.distanceSquared(
                sample.position.raw, current.position.raw
            ).squareRoot()
            guard moved <= stillWithin else { break }
            stillSince = sample.at
        }

        let still = current.at.seconds - stillSince.seconds
        return still >= stillFor ? fadedOpacity : 1
    }

    private enum Span {
        static let bothSides = 2
    }
}
