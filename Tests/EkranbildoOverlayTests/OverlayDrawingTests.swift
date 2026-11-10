import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoOverlay
import Testing

@Suite("What the overlay draws")
struct OverlayDrawingTests {

    private func overlay() -> Overlay {
        Overlay(frozen: Self.frozen)
    }

    private static let frozen = FrozenScreen(
        display: DisplayGeometry(
            displayID: 1,
            bounds: Rect(x: 0, y: 0, width: 400, height: 300),
            backingScale: 1
        ),
        image: ImageBuffer(
            width: 400,
            height: 300,
            colorSpace: .displayP3,
            pixels: [UInt8](repeating: 200, count: 400 * 300 * 4)
        ),
        windows: WindowStack(windows: [])
    )

    @Test("It draws the screen it froze")
    func drawsTheFrozenScreen() {
        let list = overlay().drawList
        #expect(list.commands.contains { if case .image = $0 { true } else { false } })
    }

    @Test("It dims what is not being chosen")
    func dimsTheRest() {
        #expect(overlay().drawList.commands.count > 1)
    }

    @Test("The canvas is the screen, in points")
    func canvasIsTheScreen() {
        let list = overlay().drawList
        #expect(list.canvas.width == 400)
        #expect(list.canvas.height == 300)
    }

    @Test("A region being swept out is drawn")
    func sweptRegionIsDrawn() {
        let before = overlay().drawList.commands.count
        let sweeping = overlay()
            .handle(.pointerDown(ScenePoint(x: 40, y: 40), Modifiers()))
            .handle(.pointerMoved(ScenePoint(x: 200, y: 160), Modifiers()))
        #expect(sweeping.drawList.commands.count > before)
    }

    @Test("Nothing it draws depends on anything but the freeze and the choice")
    func drawsOnlyFromWhatItHas() {
        let first = Overlay(frozen: Self.frozen).drawList.canonicalText
        let second = Overlay(frozen: Self.frozen).drawList.canonicalText
        #expect(first == second)
    }

    @Test("A choice changes what it draws")
    func choiceChangesTheDrawing() {
        let idle = overlay().drawList.canonicalText
        let chosen = overlay()
            .handle(.pointerDown(ScenePoint(x: 40, y: 40), Modifiers()))
            .handle(.pointerMoved(ScenePoint(x: 200, y: 160), Modifiers()))
            .drawList.canonicalText
        #expect(idle != chosen)
    }
}
