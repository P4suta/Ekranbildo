import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRender
import EkranbildoTestKit
import Testing

@Suite("Beautify")
struct BeautifyTests {

    private static let shot = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene() -> Scene {
        Scene(
            canvas: Self.shot,
            background: ImageRef(contentHash: "shot", pixelWidth: 400, pixelHeight: 300),
            annotations: [],
            style: .standard
        )
    }

    @Test("Padding grows the canvas on every side")
    func padding() {
        let framed = Beautifier(style: BeautifyStyle(padding: 40)).frame(Self.shot)
        #expect(framed.canvas.raw.width == 480)
        #expect(framed.canvas.raw.height == 380)
        #expect(framed.content.minX == 40)
        #expect(framed.content.minY == 40)
    }

    @Test("No padding leaves the picture where it was")
    func noPadding() {
        let framed = Beautifier(style: BeautifyStyle(padding: 0)).frame(Self.shot)
        #expect(framed.canvas == Self.shot)
        #expect(framed.content == Self.shot)
    }

    @Test("Negative padding is treated as none")
    func negativePadding() {
        #expect(Beautifier(style: BeautifyStyle(padding: -20)).frame(Self.shot).canvas == Self.shot)
    }

    @Test("The background is drawn behind the picture")
    func backgroundBehind() {
        let list = Beautifier(style: BeautifyStyle(padding: 30)).drawList(
            for: scene(),
            measurer: TabulatedTextMeasurer.uniform()
        )
        guard case .fill = list.commands.first else {
            Issue.record("the background should be the first thing drawn")
            return
        }
        #expect(list.commands.contains { if case .image = $0 { return true } else { return false } })
    }

    @Test("A gradient background is interpolated in linear light")
    func gradientIsLinear() {
        let midpoint = Beautifier.blend(
            Color(red: 0, green: 0, blue: 0, alpha: 1),
            Color(red: 1, green: 1, blue: 1, alpha: 1),
            at: 0.5
        )
        #expect(midpoint.red > 0.70)
        #expect(midpoint.red < 0.76)
    }

    @Test("Blending at the ends gives the ends back")
    func blendEnds() {
        let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
        let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
        #expect(Beautifier.blend(black, white, at: 0) == black)
        #expect(Beautifier.blend(black, white, at: 1) == white)
    }

    @Test("Blending outside the range is clamped")
    func blendClamps() {
        let black = Color(red: 0, green: 0, blue: 0, alpha: 1)
        let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
        #expect(Beautifier.blend(black, white, at: -1) == black)
        #expect(Beautifier.blend(black, white, at: 2) == white)
    }

    @Test("The shadow is a proportion of the room around the picture")
    func shadowScales() {
        let small = Beautifier(style: BeautifyStyle(padding: 20)).shadow()
        let large = Beautifier(style: BeautifyStyle(padding: 80)).shadow()
        #expect(large.blur > small.blur)
        #expect(large.offset.y > small.offset.y)
    }

    @Test("The shadow stays inside the room it has")
    func shadowFits() {
        let padding = 24.0
        let shadow = Beautifier(style: BeautifyStyle(padding: padding)).shadow()
        #expect(shadow.blur + shadow.offset.y <= padding)
    }

    @Test("No room means no shadow")
    func noShadowWithoutPadding() {
        #expect(Beautifier(style: BeautifyStyle(padding: 0)).shadow().blur == 0)
    }

    @Test("The shadow falls downwards")
    func shadowFalls() {
        let shadow = Beautifier(style: BeautifyStyle(padding: 40)).shadow()
        #expect(shadow.offset.y > 0)
        #expect(shadow.offset.x == 0)
    }

    @Test("Beautifying is reproducible")
    func reproducible() {
        let style = BeautifyStyle(padding: 36)
        let subject = Beautifier(style: style)
        let measurer = TabulatedTextMeasurer.uniform()
        #expect(isReproducible { subject.drawList(for: scene(), measurer: measurer) })
    }

    @Test("A scene with no picture is still framed")
    func noBackground() {
        let bare = Scene(canvas: Self.shot, background: nil, annotations: [], style: .standard)
        let list = Beautifier(style: BeautifyStyle(padding: 20)).drawList(
            for: bare,
            measurer: TabulatedTextMeasurer.uniform()
        )
        #expect(list.canvas.raw.width == 440)
        #expect(!list.commands.contains { if case .image = $0 { return true } else { return false } })
    }
}
