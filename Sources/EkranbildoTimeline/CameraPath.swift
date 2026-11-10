import EkranbildoContracts
import EkranbildoGeometry

public struct CameraEvent: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let focus: SceneRect

    public init(at: Timestamp, focus: SceneRect) {
        self.at = at
        self.focus = focus
    }
}

public struct CameraKeyframe: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let view: SceneRect

    public init(at: Timestamp, view: SceneRect) {
        self.at = at
        self.view = view
    }
}

public struct CameraPath: Hashable, Sendable, Codable {
    public let keyframes: [CameraKeyframe]

    public init(keyframes: [CameraKeyframe]) {
        self.keyframes = keyframes
    }

    public func view(at moment: Timestamp) -> SceneRect? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        if moment <= first.at { return first.view }
        if moment >= last.at { return last.view }

        for (earlier, later) in zip(keyframes, keyframes.dropFirst())
        where moment >= earlier.at && moment <= later.at {
            let span = Double(later.at.nanoseconds - earlier.at.nanoseconds)
            guard span > 0 else { return later.view }
            let position = Double(moment.nanoseconds - earlier.at.nanoseconds) / span
            return Self.between(earlier.view, later.view, at: Self.eased(position))
        }
        return last.view
    }

    static func eased(_ position: Double) -> Double {
        let clamped = min(1, max(0, position))
        return clamped * clamped * (Smoothstep.flat - Smoothstep.slope * clamped)
    }

    enum Smoothstep {
        static let flat = 3.0
        static let slope = 2.0
    }

    static func between(_ from: SceneRect, _ to: SceneRect, at position: Double) -> SceneRect {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * position }
        return SceneRect(
            x: mix(from.minX, to.minX),
            y: mix(from.minY, to.minY),
            width: mix(from.raw.width, to.raw.width),
            height: mix(from.raw.height, to.raw.height)
        )
    }
}

public struct CameraOverride: Hashable, Sendable, Codable {
    public let at: Timestamp
    public let view: SceneRect

    public init(at: Timestamp, view: SceneRect) {
        self.at = at
        self.view = view
    }
}

public struct CameraPathSolver: Sendable {
    private let maximumZoom: Double
    private let minimumRest: Double
    private let maximumSpeed: Double
    private let groupWithin: Double

    public init(
        maximumZoom: Double = Defaults.maximumZoom,
        minimumRest: Double = Defaults.minimumRest,
        maximumSpeed: Double = Defaults.maximumSpeed,
        groupWithin: Double = Defaults.groupWithin
    ) {
        self.maximumZoom = max(1, maximumZoom)
        self.minimumRest = max(0, minimumRest)
        self.maximumSpeed = max(1, maximumSpeed)
        self.groupWithin = max(0, groupWithin)
    }

    public enum Defaults {
        public static let maximumZoom: Double = 2.5
        public static let minimumRest: Double = 1.2
        public static let maximumSpeed: Double = 900
        public static let groupWithin: Double = 1.0
    }

    public func solve(
        events: [CameraEvent],
        frame: SceneRect,
        duration: Timestamp,
        overrides: [CameraOverride] = []
    ) -> CameraPath {
        let pinned = Self.pinned(overrides, within: duration)
        let wide = CameraKeyframe(at: .zero, view: frame)
        let closing = CameraKeyframe(at: duration, view: frame)

        let moments = grouped(events)
        guard !moments.isEmpty else {
            return CameraPath(keyframes: Self.applying(pinned, to: [wide, closing]))
        }

        var keyframes: [CameraKeyframe] = [wide]
        for moment in moments {
            let view = framing(moment.focus, in: frame)

            let arrive = Self.after(
                keyframes.last?.at ?? .zero,
                atLeast: travelTime(
                    from: keyframes.last?.view ?? frame, to: view), butNotBefore: moment.at)
            let leave = Timestamp.seconds(arrive.seconds + minimumRest)

            guard leave.seconds < duration.seconds else { continue }
            keyframes.append(CameraKeyframe(at: arrive, view: view))
            keyframes.append(CameraKeyframe(at: leave, view: view))
        }

        let pullBack = Self.after(
            keyframes.last?.at ?? .zero,
            atLeast: travelTime(from: keyframes.last?.view ?? frame, to: frame),
            butNotBefore: .zero
        )
        if pullBack.seconds < duration.seconds {
            keyframes.append(CameraKeyframe(at: pullBack, view: frame))
        }
        keyframes.append(closing)

        return CameraPath(keyframes: Self.applying(pinned, to: keyframes))
    }

    static func pinned(_ overrides: [CameraOverride], within duration: Timestamp)
        -> [CameraKeyframe]
    {
        var byMoment: [(at: Timestamp, view: SceneRect)] = []
        for override in overrides {
            let at = Timeline.clamped(override.at, to: duration)
            if let existing = byMoment.firstIndex(where: { $0.at == at }) {
                byMoment[existing] = (at, override.view)
            } else {
                byMoment.append((at, override.view))
            }
        }
        return
            byMoment
            .map { CameraKeyframe(at: $0.at, view: $0.view) }
            .sorted { $0.at == $1.at ? $0.view.minX < $1.view.minX : $0.at < $1.at }
    }

    static func applying(_ pinned: [CameraKeyframe], to solved: [CameraKeyframe])
        -> [CameraKeyframe]
    {
        guard !pinned.isEmpty else { return ordered(solved) }
        let taken = pinned.map(\.at)
        return ordered(solved.filter { !taken.contains($0.at) } + pinned)
    }

    func grouped(_ events: [CameraEvent]) -> [CameraEvent] {
        let ordered = events.sorted {
            $0.at == $1.at ? $0.focus.minX < $1.focus.minX : $0.at < $1.at
        }
        var grouped: [CameraEvent] = []
        for event in ordered {
            guard let last = grouped.last,
                event.at.seconds - last.at.seconds <= groupWithin,
                Geo.overlaps(last.focus.raw, event.focus.raw)
            else {
                grouped.append(event)
                continue
            }
            continue
        }
        return grouped
    }

    func framing(_ focus: SceneRect, in frame: SceneRect) -> SceneRect {
        let needed = max(
            focus.raw.width * Framing.margin / frame.raw.width,
            focus.raw.height * Framing.margin / frame.raw.height
        )

        let scale = min(1, max(1 / maximumZoom, needed))
        let viewWidth = frame.raw.width * scale
        let viewHeight = frame.raw.height * scale

        let x = focus.raw.center.x - Geo.half(viewWidth)
        let y = focus.raw.center.y - Geo.half(viewHeight)
        return SceneRect(
            x: min(max(frame.minX, x), frame.maxX - viewWidth),
            y: min(max(frame.minY, y), frame.maxY - viewHeight),
            width: viewWidth,
            height: viewHeight
        )
    }

    func travelTime(from: SceneRect, to: SceneRect) -> Double {
        let distance = Geo.distanceSquared(from.raw.center, to.raw.center).squareRoot()
        return distance / maximumSpeed
    }

    private static func after(
        _ moment: Timestamp,
        atLeast seconds: Double,
        butNotBefore wanted: Timestamp
    ) -> Timestamp {
        Timestamp.seconds(max(moment.seconds + seconds, wanted.seconds))
    }

    static func ordered(_ keyframes: [CameraKeyframe]) -> [CameraKeyframe] {
        keyframes.sorted { $0.at == $1.at ? $0.view.minX < $1.view.minX : $0.at < $1.at }
    }

    private enum Framing {
        static let margin: Double = 3
    }
}
