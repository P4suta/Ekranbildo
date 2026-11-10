import EkranbildoContracts
import EkranbildoCore

public struct CursorKeyframe: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let position: ScenePoint
    public let opacity: Double

    public init(at: Timestamp, position: ScenePoint, opacity: Double = 1) {
        self.at = at
        self.position = position
        self.opacity = opacity
    }
}

public struct RippleKeyframe: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let centre: ScenePoint

    public init(at: Timestamp, centre: ScenePoint) {
        self.at = at
        self.centre = centre
    }
}

public struct CursorTrack: Hashable, Sendable, Codable {
    public let samples: [CursorKeyframe]
    public let ripples: [RippleKeyframe]
    public let rippleFor: Timestamp

    public init(
        samples: [CursorKeyframe],
        ripples: [RippleKeyframe] = [],
        rippleFor: Timestamp = Defaults.rippleFor
    ) {
        self.samples = samples
        self.ripples = ripples
        self.rippleFor = rippleFor
    }

    public enum Defaults {
        public static let rippleFor = Timestamp.seconds(0.35)
    }

    public func cursor(at moment: Timestamp) -> Cursor? {
        guard let position = interpolated(at: moment) else { return nil }
        return Cursor(
            position: position.point,
            opacity: position.opacity,
            ripple: rippleProgress(at: moment)
        )
    }

    public init(
        recorded samples: [CursorSample],
        geometry: CaptureGeometry,
        polish: CursorPolish = CursorPolish(),
        rippleFor: Timestamp = Defaults.rippleFor
    ) {
        let smoothed = polish.smooth(samples)
        self.init(
            samples: smoothed.map {
                CursorKeyframe(
                    at: $0.at,
                    position: geometry.scenePoint(of: $0.position),
                    opacity: polish.opacity(at: $0.at, in: smoothed)
                )
            },
            ripples: polish.ripples(in: smoothed).map {
                RippleKeyframe(at: $0.at, centre: geometry.scenePoint(of: $0.centre))
            },
            rippleFor: rippleFor
        )
    }

    private func interpolated(at moment: Timestamp) -> (point: ScenePoint, opacity: Double)? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if moment <= first.at { return (first.position, first.opacity) }
        if moment >= last.at { return (last.position, last.opacity) }

        guard let next = samples.firstIndex(where: { $0.at > moment }), next > 0 else {
            return (last.position, last.opacity)
        }
        let before = samples[next - 1]
        let after = samples[next]

        let span = after.at.nanoseconds - before.at.nanoseconds
        guard span > 0 else { return (before.position, before.opacity) }
        let position = Double(moment.nanoseconds - before.at.nanoseconds) / Double(span)

        return (
            ScenePoint(
                x: Interpolate.between(before.position.x, after.position.x, at: position),
                y: Interpolate.between(before.position.y, after.position.y, at: position)
            ),
            Interpolate.between(before.opacity, after.opacity, at: position)
        )
    }

    private func rippleProgress(at moment: Timestamp) -> Double? {
        let span = rippleFor.nanoseconds
        guard span > 0 else { return nil }

        var best: Double?
        for ripple in ripples {
            let since = moment.nanoseconds - ripple.at.nanoseconds
            guard since >= 0, since < span else { continue }
            let progress = Double(since) / Double(span)
            if best.map({ progress < $0 }) ?? true { best = progress }
        }
        return best
    }

    private enum Interpolate {
        static func between(_ from: Double, _ to: Double, at position: Double) -> Double {
            if position <= 0 { return from }
            if position >= 1 { return to }
            return from + (to - from) * position
        }
    }
}
