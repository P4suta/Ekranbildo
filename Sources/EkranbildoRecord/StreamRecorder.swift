import EkranbildoContracts

public protocol FrameSource: Sendable {
    func deliveries() -> [FrameDelivery]
}

public protocol LiveFrameSource: Sendable {
    func deliveries() -> AsyncStream<FrameDelivery>
}

public enum FrameDelivery: Sendable {
    case frame(ImageBuffer, at: Timestamp)
    case cursor(CursorSample)
    case event(RecordedEvent)
    case dropped(Int, at: Timestamp)
    case interrupted(RecordingError)
}

public struct SourceRecorder: Sendable {
    private let geometry: CaptureGeometry

    public init(geometry: CaptureGeometry) {
        self.geometry = geometry
    }

    public func record(from source: any FrameSource) throws -> RecordedRun {
        var recorder = Recorder(geometry: geometry)
        try recorder.start()
        for delivery in source.deliveries() {
            Self.take(delivery, into: &recorder)
        }
        return RecordedRun(recording: try recorder.finish(), assets: recorder.assets)
    }

    public func record(from source: any LiveFrameSource) async throws -> RecordedRun {
        var recorder = Recorder(geometry: geometry)
        try recorder.start()
        for await delivery in source.deliveries() {
            Self.take(delivery, into: &recorder)
        }
        return RecordedRun(recording: try recorder.finish(), assets: recorder.assets)
    }

    private static func take(_ delivery: FrameDelivery, into recorder: inout Recorder) {
        switch delivery {
        case .frame(let image, let time):
            try? recorder.append(image, at: time)
        case .cursor(let sample):
            recorder.append(sample)
        case .event(let event):
            recorder.append(event)
        case .dropped(let count, let time):
            recorder.noteDroppedFrames(count, at: time)
        case .interrupted(let error):
            recorder.interrupt(error)
        }
    }
}

public struct RecordedRun: Sendable {
    public let recording: Recording
    public let assets: InMemoryAssetStore

    public init(recording: Recording, assets: InMemoryAssetStore) {
        self.recording = recording
        self.assets = assets
    }
}
