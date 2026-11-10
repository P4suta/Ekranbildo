@testable import EkranbildoContracts
import Testing

@Suite("Contrast")
struct ContrastTests {
    private let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    private let black = Color(red: 0, green: 0, blue: 0, alpha: 1)

    @Test("Black on white is twenty-one to one")
    func extremes() {
        #expect(approximately(white.contrastRatio(against: black), 21))
        #expect(approximately(black.contrastRatio(against: white), 21))
    }

    @Test("A colour against itself is one to one")
    func identical() {
        #expect(approximately(white.contrastRatio(against: white), 1))
        #expect(approximately(black.contrastRatio(against: black), 1))
    }

    @Test("It does not matter which is called the background")
    func symmetric() {
        let red = Color(red: 0.86, green: 0.16, blue: 0.16, alpha: 1)
        #expect(
            approximately(
                red.contrastRatio(against: white), white.contrastRatio(against: red)))
    }

    @Test("Luminance follows the published curve on both sides of its kink")
    func luminanceCurve() {
        let verydark = Color(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        #expect(approximately(verydark.relativeLuminance, 0.02 / 12.92))

        let mid = Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        #expect(mid.relativeLuminance > 0.2)
        #expect(mid.relativeLuminance < 0.22)
    }

    @Test("The channels are weighted the way the eye weighs them")
    func channelWeights() {
        let red = Color(red: 1, green: 0, blue: 0, alpha: 1)
        let green = Color(red: 0, green: 1, blue: 0, alpha: 1)
        let blue = Color(red: 0, green: 0, blue: 1, alpha: 1)

        #expect(green.relativeLuminance > red.relativeLuminance)
        #expect(red.relativeLuminance > blue.relativeLuminance)
    }

    @Test("A translucent colour is asked about as what it actually looks like")
    func translucent() {
        let front = Color(red: 1, green: 0.4, blue: 0, alpha: 0.5)
        let back = Color(red: 0, green: 0.8, blue: 0.6, alpha: 1)
        let over = front.composited(over: back)

        #expect(over.alpha == 1)
        #expect(approximately(over.red, 0.5))
        #expect(approximately(over.green, 0.6))
        #expect(approximately(over.blue, 0.3))
    }

    @Test("A fully opaque colour is unchanged by what is behind it")
    func opaqueIsUnchanged() {
        #expect(white.composited(over: black) == white)
    }

    @Test("A fully transparent colour is whatever is behind it")
    func transparentIsTheBackground() {
        let invisible = Color(red: 1, green: 0, blue: 0, alpha: 0)
        #expect(invisible.composited(over: black) == black)
    }

    private func approximately(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 1e-6
    }
}
