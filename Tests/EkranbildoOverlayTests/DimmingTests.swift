import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoOverlay
import Testing

@Suite("What is dark while choosing")
struct DimmingTests {

    private static let display = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 800, height: 600),
        backingScale: 1
    )

    private static func overlay() -> Overlay {
        Overlay(
            frozen: FrozenScreen(
                display: display,
                image: ImageBuffer(
                    width: 800,
                    height: 600,
                    colorSpace: .displayP3,
                    pixels: [UInt8](repeating: 128, count: 800 * 600 * 4)
                ),
                windows: WindowStack(windows: [])
            )
        )
    }

    private func choosing(_ region: Rect) -> Overlay {
        Self.overlay()
            .handle(.pointerDown(ScenePoint(x: region.minX, y: region.minY), [.option]))
            .handle(.pointerMoved(ScenePoint(x: region.maxX, y: region.maxY), [.option]))
    }

    private func images(_ overlay: Overlay) -> [SceneRect] {
        overlay.drawList.commands.compactMap { command -> SceneRect? in
            guard case .image(_, let rect, _, _) = command else { return nil }
            return rect
        }
    }

    private func dimmed(_ overlay: Overlay) -> [SceneRect] {
        overlay.drawList.commands.compactMap { command -> SceneRect? in
            guard case .fill(let path, _) = command else { return nil }
            return path.bounds
        }
    }

    @Test("The picture is drawn once, over the whole screen")
    func thePictureIsWholeAndOnlyOnce() {
        let drawn = images(choosing(Rect(x: 100, y: 80, width: 300, height: 200)))
        #expect(drawn == [SceneRect(Self.display.bounds)])
    }

    @Test("Before anything is chosen, everything is dimmed")
    func dimmedAllOver() {
        #expect(dimmed(Self.overlay()) == [SceneRect(Self.display.bounds)])
    }

    @Test(
        "What is chosen is not dimmed, and everything else is, exactly once",
        arguments: [
            Rect(x: 100, y: 80, width: 300, height: 200),
            Rect(x: 0, y: 0, width: 400, height: 300),
            Rect(x: 400, y: 300, width: 400, height: 300),
            Rect(x: 0, y: 200, width: 800, height: 100),
            Rect(x: 350, y: 0, width: 100, height: 600),
        ]
    )
    func dimmedAroundTheSelection(_ region: Rect) {
        let parts = dimmed(choosing(region))
        let whole = Self.display.bounds

        for part in parts {
            #expect(part.raw.intersection(region) == nil)
        }
        for (index, part) in parts.enumerated() {
            for other in parts[(index + 1)...] {
                #expect(part.raw.intersection(other.raw) == nil)
            }
        }
        let covered = parts.reduce(0.0) { $0 + $1.raw.area } + region.area
        #expect(covered == whole.area)
        for part in parts {
            #expect(whole.contains(part.raw))
        }
    }

    @Test("A selection of the whole screen dims nothing")
    func nothingLeftToDim() {
        #expect(dimmed(choosing(Self.display.bounds)).isEmpty)
    }

    @Test("The chosen region is outlined so its edge can be seen")
    func outlined() {
        let region = Rect(x: 100, y: 80, width: 300, height: 200)
        let strokes = choosing(region).drawList.commands.compactMap { command -> SceneRect? in
            guard case .stroke(let path, _) = command else { return nil }
            return path.bounds
        }
        #expect(strokes == [SceneRect(region)])
    }
}
