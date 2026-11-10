@testable import EkranbildoContracts
import Testing

@Suite("Colour vision")
struct ColorVisionTests {
    private let red = Color(red: 0.86, green: 0.16, blue: 0.16, alpha: 1)
    private let green = Color(red: 0.16, green: 0.66, blue: 0.26, alpha: 1)
    private let white = Color(red: 1, green: 1, blue: 1, alpha: 1)
    private let black = Color(red: 0, green: 0, blue: 0, alpha: 1)

    @Test("Grey is unchanged for everybody", arguments: ColorVision.allCases)
    func greyIsUnchanged(vision: ColorVision) {
        let grey = Color(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let seen = grey.seen(with: vision)
        #expect(approximately(seen.red, seen.green))
        #expect(approximately(seen.green, seen.blue))
    }

    @Test("Black and white are unchanged for everybody", arguments: ColorVision.allCases)
    func extremesAreUnchanged(vision: ColorVision) {
        #expect(approximately(white.seen(with: vision).relativeLuminance, white.relativeLuminance))
        #expect(approximately(black.seen(with: vision).relativeLuminance, black.relativeLuminance))
    }

    @Test("Seeing as everybody else does changes nothing")
    func typicalChangesNothing() {
        #expect(red.seen(with: .typical) == red)
        #expect(green.seen(with: .typical) == green)
    }

    @Test(
        "Red and green come much closer together",
        arguments: [ColorVision.protanopia, .deuteranopia]
    )
    func redAndGreenConverge(vision: ColorVision) {
        let apart = distance(red, green)
        let closer = distance(red.seen(with: vision), green.seen(with: vision))
        #expect(closer < apart / 2, "they stayed \(closer) apart, from \(apart)")
    }

    @Test("Green and cyan come together for the third kind")
    func greenAndCyanConverge() {
        let cyan = Color(red: 0.1, green: 0.7, blue: 0.7, alpha: 1)

        let apart = distance(green, cyan)
        let closer = distance(green.seen(with: .tritanopia), cyan.seen(with: .tritanopia))
        #expect(closer < apart / 4, "they stayed \(closer) apart, from \(apart)")
    }

    @Test("Red goes dark without the long cone, and does not without the middle one")
    func redDarkensForProtanopia() {
        let asProtanope = red.seen(with: .protanopia).relativeLuminance
        let asDeuteranope = red.seen(with: .deuteranopia).relativeLuminance

        #expect(asProtanope < red.relativeLuminance * Tolerances.darkened)
        #expect(asDeuteranope > asProtanope)
    }

    @Test("Losing the short cone barely changes how bright anything is")
    func tritanopiaKeepsBrightness() {
        for color in [red, green, Color(red: 0.95, green: 0.85, blue: 0.1, alpha: 1)] {
            let seen = color.seen(with: .tritanopia).relativeLuminance
            let moved = abs(seen - color.relativeLuminance) / color.relativeLuminance
            #expect(
                moved < Tolerances.shortConeBrightness,
                "brightness moved by \(moved): \(color.relativeLuminance) -> \(seen)"
            )
        }
    }

    @Test("A simulated colour is still a colour", arguments: ColorVision.allCases)
    func staysInRange(vision: ColorVision) {
        for color in [red, green, white, black] {
            let seen = color.seen(with: vision)
            for channel in [seen.red, seen.green, seen.blue] {
                #expect(channel >= 0 && channel <= 1)
            }
            #expect(seen.alpha == color.alpha)
        }
    }

    @Test("Transparency is carried through", arguments: ColorVision.allCases)
    func alphaSurvives(vision: ColorVision) {
        let translucent = Color(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.4)
        #expect(translucent.seen(with: vision).alpha == 0.4)
    }

    private func distance(_ a: Color, _ b: Color) -> Double {
        let red = a.red - b.red
        let green = a.green - b.green
        let blue = a.blue - b.blue
        return (red * red + green * green + blue * blue).squareRoot()
    }

    private func approximately(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < Tolerances.roundTrip
    }

    private enum Tolerances {
        static let roundTrip = 1e-4
        static let darkened = 0.8
        static let shortConeBrightness = 0.1
    }
}
