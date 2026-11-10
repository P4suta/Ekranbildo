import EkranbildoContracts

public enum TimelineEvent: Hashable, Sendable, Codable {
    case scrubbed(to: Timestamp)
    case pinned(SceneRect)
    case keyframeTouched(at: Timestamp)
    case keyframeMoved(to: Timestamp)
    case keyframeRemoved
}

public struct TimelineState: Hashable, Sendable {
    public let frame: SceneRect
    public let duration: Timestamp
    public let events: [CameraEvent]
    public let overrides: [CameraOverride]
    public let playhead: Timestamp
    public let selected: Timestamp?

    public init(
        frame: SceneRect,
        duration: Timestamp,
        events: [CameraEvent],
        overrides: [CameraOverride],
        playhead: Timestamp,
        selected: Timestamp?
    ) {
        self.frame = frame
        self.duration = duration
        self.events = events
        self.overrides = overrides
        self.playhead = playhead
        self.selected = selected
    }

    fileprivate func with(
        overrides: [CameraOverride]? = nil,
        playhead: Timestamp? = nil,
        selected: Timestamp?? = nil
    ) -> Self {
        Self(
            frame: frame,
            duration: duration,
            events: events,
            overrides: overrides ?? self.overrides,
            playhead: playhead ?? self.playhead,
            selected: selected ?? self.selected
        )
    }
}

public struct TimelineInteractor: Sendable {
    private let solver: CameraPathSolver

    public init(solver: CameraPathSolver = CameraPathSolver()) {
        self.solver = solver
    }

    public struct Outcome: Sendable {
        public let state: TimelineState
    }

    public func handle(_ event: TimelineEvent, in state: TimelineState) -> Outcome {
        switch event {
        case .scrubbed(let moment):
            return Outcome(state: state.with(playhead: Timeline.clamped(moment, to: state.duration)))

        case .pinned(let view):
            let at = state.playhead
            return Outcome(
                state: state.with(
                    overrides: Self.replacing(at: at, with: view, in: state.overrides),
                    selected: .some(at)
                ))

        case .keyframeTouched(let moment):
            guard let found = state.overrides.first(where: { $0.at == moment }) else {
                return Outcome(state: state.with(selected: .some(nil)))
            }
            return Outcome(state: state.with(playhead: found.at, selected: .some(found.at)))

        case .keyframeMoved(let moment):
            guard let selected = state.selected,
                let held = state.overrides.first(where: { $0.at == selected })
            else { return Outcome(state: state) }

            let at = Timeline.clamped(moment, to: state.duration)
            let remaining = state.overrides.filter { $0.at != selected }
            return Outcome(
                state: state.with(
                    overrides: Self.replacing(at: at, with: held.view, in: remaining),
                    playhead: at,
                    selected: .some(at)
                ))

        case .keyframeRemoved:
            guard let selected = state.selected else { return Outcome(state: state) }
            return Outcome(
                state: state.with(
                    overrides: state.overrides.filter { $0.at != selected },
                    selected: .some(nil)
                ))
        }
    }

    public func path(of state: TimelineState) -> CameraPath {
        solver.solve(
            events: state.events,
            frame: state.frame,
            duration: state.duration,
            overrides: state.overrides
        )
    }

    static func replacing(
        at moment: Timestamp,
        with view: SceneRect,
        in overrides: [CameraOverride]
    ) -> [CameraOverride] {
        (overrides.filter { $0.at != moment } + [CameraOverride(at: moment, view: view)])
            .sorted { $0.at < $1.at }
    }
}
