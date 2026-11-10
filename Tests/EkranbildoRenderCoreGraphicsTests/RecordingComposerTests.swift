import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoRenderCoreGraphics
import EkranbildoTimeline
import Testing

@Suite("Composing a recording")
struct RecordingComposerTests {
    private let canvas = SceneRect(x: 0, y: 0, width: 40, height: 30)

    private func frame() -> ImageBuffer {
        ImageBuffer(
            width: Int(canvas.width),
            height: Int(canvas.height),
            colorSpace: .displayP3,
            pixels: [UInt8](
                repeating: 0,
                count: Int(canvas.width) * Int(canvas.height) * ImageBuffer.Channel.count)
        )
    }

    private func composer(keys: [Keystroke], cursor: CursorTrack? = nil) -> RecordingComposer {
        RecordingComposer(
            timeline: Timeline(
                canvas: canvas,
                style: .standard,
                background: ImageRef(contentHash: "ignored", pixelWidth: 1, pixelHeight: 1),
                duration: .seconds(10),
                tracks: [],
                cursor: cursor,
                keys: keys.isEmpty ? nil : KeystrokeTrack(recorded: keys)
            ),
            measurer: TabulatedTextMeasurer.uniform(),
            framesPerSecond: Frames.perSecond
        )
    }

    @Test("A frame moves through untouched when there is nothing to draw on it")
    func untouched() {
        let original = frame()
        #expect(composer(keys: []).compose(original, at: 0) == original)
    }

    @Test("The frame a key was pressed on comes back changed")
    func changedWhenTyped() {
        let original = frame()
        let typed = composer(keys: [Keystroke(at: .zero, cap: "A", modifiers: [])])
        #expect(typed.compose(original, at: 0) != original)
    }

    @Test("A frame from long after the key was let go is untouched again")
    func untouchedLater() {
        let original = frame()
        let typed = composer(keys: [Keystroke(at: .zero, cap: "A", modifiers: [])])
        #expect(typed.compose(original, at: Frames.perSecond * Frames.wellAfter) == original)
    }

    @Test("A composed frame keeps the size it came in at")
    func keepsItsSize() {
        let typed = composer(keys: [Keystroke(at: .zero, cap: "A", modifiers: [])])
        let composed = typed.compose(frame(), at: 0)
        #expect(composed.width == Int(canvas.width))
        #expect(composed.height == Int(canvas.height))
    }

    @Test("The same recording composes the same way twice")
    func deterministic() {
        let typed = composer(keys: [Keystroke(at: .zero, cap: "A", modifiers: [])])
        let once = typed.compose(frame(), at: 0)
        let again = typed.compose(frame(), at: 0)
        #expect(once == again)
    }

    @Test("A frame number reads as the moment it happens at")
    func moments() {
        let empty = composer(keys: [])
        #expect(empty.moment(of: 0) == .zero)
        #expect(empty.moment(of: Frames.perSecond) == .seconds(1))
    }

    @Test("Composing every frame gives back as many frames as went in")
    func everyFrame() {
        let typed = composer(keys: [Keystroke(at: .zero, cap: "A", modifiers: [])])
        let frames = [frame(), frame(), frame()]
        #expect(typed.compose(frames).count == frames.count)
    }

    private enum Frames {
        static let perSecond = 30
        static let wellAfter = 9
    }
}
