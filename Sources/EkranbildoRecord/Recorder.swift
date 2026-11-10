import EkranbildoContracts

public struct Recorder: Sendable {
    private let geometry: CaptureGeometry

    public private(set) var assets = InMemoryAssetStore()

    private var state: State = .ready
    private var frames: [RecordedFrame] = []
    private var cursor: [CursorSample] = []
    private var events: [RecordedEvent] = []
    private var dropped = 0
    private var arrivals = 0

    private enum State {
        case ready
        case recording
        case interrupted(RecordingError)
        case finished
    }

    public init(geometry: CaptureGeometry) {
        self.geometry = geometry
    }

    public mutating func start() throws {
        guard case .ready = state else {
            throw RecordingError(
                code: RecordingError.wrongState,
                detail: "this recorder has already been used"
            )
        }
        state = .recording
    }

    public mutating func append(_ image: ImageBuffer, at time: Timestamp) throws {
        try requireRecording()
        guard time.nanoseconds >= 0 else {
            throw RecordingError(
                code: RecordingError.wrongState,
                detail: "a frame cannot arrive before the recording started"
            )
        }

        let ref = assets.store(image)
        frames.append(RecordedFrame(presentedAt: time, image: ref, sequence: arrivals))
        arrivals += 1
    }

    public mutating func append(_ sample: CursorSample) {
        guard case .recording = state else { return }
        cursor.append(sample)
    }

    public mutating func append(_ event: RecordedEvent) {
        guard case .recording = state else { return }
        events.append(event)
    }

    public mutating func noteDroppedFrames(_ count: Int, at time: Timestamp = .zero) {
        guard case .recording = state, count > 0 else { return }
        dropped += count
        events.append(RecordedEvent(at: time, kind: .framesDropped))
    }

    public mutating func interrupt(_ error: RecordingError) {
        guard case .recording = state else { return }
        state = .interrupted(error)
    }

    public mutating func finish() throws -> Recording {
        switch state {
        case .ready, .finished:
            throw RecordingError(
                code: RecordingError.wrongState,
                detail: "there is no recording in progress"
            )
        case .recording, .interrupted:
            state = .finished
        }

        return Recording(
            geometry: geometry,
            frames: Self.ordered(frames),
            cursor: cursor.sorted { ($0.at, $0.position.x) < ($1.at, $1.position.x) },
            events: events.sorted { ($0.at, $0.kind.rawValue) < ($1.at, $1.kind.rawValue) },
            droppedFrameCount: dropped
        )
    }

    private func requireRecording() throws {
        switch state {
        case .recording:
            return
        case .interrupted(let error):
            throw error
        case .ready:
            throw RecordingError(
                code: RecordingError.wrongState,
                detail: "the recording has not been started"
            )
        case .finished:
            throw RecordingError(
                code: RecordingError.wrongState,
                detail: "the recording has already finished"
            )
        }
    }

    static func ordered(_ frames: [RecordedFrame]) -> [RecordedFrame] {
        var latest: [RecordedFrame] = []
        for frame in frames.sorted(by: { ($0.presentedAt, $0.sequence) < ($1.presentedAt, $1.sequence) }) {
            if latest.last?.presentedAt == frame.presentedAt {
                latest.removeLast()
            }
            latest.append(frame)
        }
        return latest
    }
}
