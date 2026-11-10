import EkranbildoContracts
import EkranbildoCore
import EkranbildoImaging
import EkranbildoRender
import EkranbildoTimeline

public struct RecordingComposer: Sendable {
    private let timeline: Timeline
    private let measurer: any TextMeasuring
    private let framesPerSecond: Int

    public init(timeline: Timeline, measurer: any TextMeasuring, framesPerSecond: Int) {
        self.timeline = timeline
        self.measurer = measurer
        self.framesPerSecond = max(1, framesPerSecond)
    }

    public func moment(of frame: Int) -> Timestamp {
        .seconds(Double(frame) / Double(framesPerSecond))
    }

    public func overlay(at frame: Int) -> DrawList {
        let scene = timeline.scene(at: moment(of: frame)).replacing(background: .some(nil))
        return DrawListBuilder(measurer: measurer).build(scene)
    }

    public func compose(_ picture: ImageBuffer, at frame: Int) -> ImageBuffer {
        let list = overlay(at: frame)
        guard !list.commands.isEmpty else { return picture }
        guard let drawn = try? CoreGraphicsRenderer().render(list, over: picture) else {
            return picture
        }
        return drawn.bitmap.imageBuffer
    }

    public func compose(_ frames: [ImageBuffer]) -> [ImageBuffer] {
        frames.enumerated().map { compose($0.element, at: $0.offset) }
    }
}
