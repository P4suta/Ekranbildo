import CoreMedia
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoRecord
import Foundation
import ScreenCaptureKit
import VideoToolbox

public final class StreamFrameSource: NSObject, LiveFrameSource, SCStreamOutput,
    SCStreamDelegate, @unchecked Sendable
{
    private let filter: SCContentFilter
    private let configuration: SCStreamConfiguration
    private let display: DisplayGeometry
    private let pointer: any PointerReader

    private let lock = NSLock()
    private var continuation: AsyncStream<FrameDelivery>.Continuation?
    private var stream: SCStream?
    private var startedAt: CMTime?
    private var sampler = PointerSampler()
    private var pointerTimer: DispatchSourceTimer?

    public init(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        display: DisplayGeometry,
        pointer: any PointerReader = SystemPointerReader()
    ) {
        self.filter = filter
        self.configuration = configuration
        self.display = display
        self.pointer = pointer
    }

    public func deliveries() -> AsyncStream<FrameDelivery> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }

            do {
                let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try stream.addStreamOutput(
                    self, type: .screen, sampleHandlerQueue: DispatchQueue(label: Queue.label))
                self.stream = stream
                startWatchingThePointer()
                stream.startCapture { error in
                    guard let error else { return }
                    continuation.yield(
                        .interrupted(
                            RecordingError(
                                code: RecordingError.interrupted,
                                detail: "the recording would not start: \(error)"
                            )
                        )
                    )
                    continuation.finish()
                }
            } catch {
                continuation.yield(
                    .interrupted(
                        RecordingError(
                            code: RecordingError.interrupted,
                            detail: "the recording could not be set up: \(error)"
                        )
                    )
                )
                continuation.finish()
            }
        }
    }

    public func stop() {
        lock.lock()
        let running = stream
        let continuation = self.continuation
        let timer = pointerTimer
        stream = nil
        pointerTimer = nil
        lock.unlock()

        timer?.cancel()
        running?.stopCapture { _ in }
        continuation?.finish()
    }

    private func startWatchingThePointer() {
        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: Queue.pointerLabel))
        timer.schedule(
            deadline: .now(),
            repeating: .nanoseconds(Int(Sampling.interval.nanoseconds))
        )
        timer.setEventHandler { [weak self] in self?.lookAtThePointer() }
        pointerTimer = timer
        timer.resume()
    }

    private func lookAtThePointer() {
        let reading = pointer.read()
        let moment = elapsedFromHostClock()

        lock.lock()
        let sample = sampler.sample(reading, at: moment)
        lock.unlock()

        guard let sample else { return }
        deliver(.cursor(sample))
    }

    private func elapsedFromHostClock() -> Timestamp {
        lock.lock()
        let start = startedAt
        lock.unlock()
        guard start != nil else { return .zero }
        return elapsed(to: CMClockGetTime(CMClockGetHostTimeClock()))
    }

    public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen, sampleBuffer.isValid else { return }

        guard Self.carriesNewContent(sampleBuffer) else { return }

        guard let pixels = sampleBuffer.imageBuffer,
            let image = Self.buffer(from: pixels)
        else {
            deliver(
                .interrupted(
                    RecordingError(
                        code: RecordingError.interrupted,
                        detail: "a frame arrived that could not be read"
                    )
                )
            )
            return
        }

        deliver(.frame(image, at: elapsed(to: sampleBuffer.presentationTimeStamp)))
    }

    public func stream(_ stream: SCStream, didStopWithError error: any Error) {
        deliver(
            .interrupted(
                RecordingError(
                    code: RecordingError.interrupted,
                    detail: "the system stopped the recording: \(error)"
                )
            )
        )
        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.finish()
    }

    private func elapsed(to presentation: CMTime) -> Timestamp {
        lock.lock()
        if startedAt == nil { startedAt = presentation }
        let start = startedAt ?? presentation
        lock.unlock()

        let offset = CMTimeSubtract(presentation, start)
        guard offset.isValid, offset.isNumeric else { return .zero }
        return Timestamp(
            nanoseconds: Int64(
                (CMTimeGetSeconds(offset) * Double(Scale.nanosecondsPerSecond)).rounded()))
    }

    private func deliver(_ delivery: FrameDelivery) {
        lock.lock()
        let continuation = self.continuation
        lock.unlock()
        continuation?.yield(delivery)
    }

    static func carriesNewContent(_ sampleBuffer: CMSampleBuffer) -> Bool {
        let attachments =
            CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        let raw = attachments?.first?[.status] as? Int
        return isNewContent(raw.flatMap(SCFrameStatus.init(rawValue:)))
    }

    static func isNewContent(_ status: SCFrameStatus?) -> Bool {
        guard let status else { return true }
        return status == .complete
    }

    static func buffer(from pixels: CVPixelBuffer) -> ImageBuffer? {
        var image: CGImage?
        guard
            VTCreateCGImageFromCVPixelBuffer(pixels, options: nil, imageOut: &image) == noErr,
            let image
        else { return nil }
        return try? ImageCodec.buffer(from: image)
    }

    private enum Queue {
        static let label = "app.ekranbildo.capture.frames"
        static let pointerLabel = "app.ekranbildo.capture.pointer"
    }

    private enum Sampling {
        static let interval = Timestamp.seconds(1 / Double(looksPerSecond))
        private static let looksPerSecond = 60
    }

    private enum Scale {
        static let nanosecondsPerSecond: Int64 = 1_000_000_000
    }
}
