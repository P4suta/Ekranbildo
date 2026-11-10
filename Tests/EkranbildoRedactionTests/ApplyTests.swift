import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoRedaction
import EkranbildoTestKit
import Testing

@Suite("Applying a mask")
struct ApplyTests {

    private static let secret = SceneRect(x: 40, y: 30, width: 80, height: 20)

    private func screen() -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        for column in 0..<10 {
            screen.paint(
                SceneRect(x: 40 + Double(column) * 8, y: 30, width: 4, height: 20),
                color: .opaque(red: 20, green: 20, blue: 20)
            )
        }
        return screen.image
    }

    @Test("The pixels under a mask are not what they were", arguments: MaskStyle.allCases)
    func pixelsChange(style: MaskStyle) throws {
        let before = screen()
        let after = Redactor().apply([Mask(rect: Self.secret, style: style)], to: before)

        var changed = 0
        for y in 30..<50 {
            for x in 40..<120 where after[x: x, y: y] != before[x: x, y: y] {
                changed += 1
            }
        }
        #expect(changed > 0, "\(style) changed nothing at all")
    }

    @Test("The irreversible styles leave nothing to recover")
    func irreversible() {
        let before = screen()
        for style in MaskStyle.allCases where style.isIrreversible {
            let after = Redactor().apply([Mask(rect: Self.secret, style: style)], to: before)
            let sample = after[x: 42, y: 32]
            var identical = true
            for y in 32..<36 {
                for x in 42..<46 where after[x: x, y: y] != sample {
                    identical = false
                }
            }
            #expect(identical, "\(style) left detail behind")
        }
    }

    @Test("Every way of hiding something is one that cannot be undone")
    func everyStyleIsAGuarantee() {
        #expect(MaskStyle.allCases.allSatisfy { $0.isIrreversible })
    }

    @Test("Nothing outside a mask is touched")
    func leavesTheRestAlone() {
        let before = screen()
        let after = Redactor().apply([Mask(rect: Self.secret, style: .solid)], to: before)

        for y in 0..<before.height {
            for x in 0..<before.width where !Self.secret.raw.contains(P2(x: Double(x), y: Double(y))) {
                #expect(after[x: x, y: y] == before[x: x, y: y], "\(x),\(y) changed")
            }
        }
    }

    @Test("Several masks are all applied")
    func severalMasks() {
        let before = screen()
        let second = SceneRect(x: 10, y: 80, width: 30, height: 20)
        let after = Redactor().apply(
            [
                Mask(rect: Self.secret, style: .solid),
                Mask(rect: second, style: .solid),
            ],
            to: before
        )
        #expect(after[x: 50, y: 35] != before[x: 50, y: 35])
        #expect(after[x: 20, y: 90] != before[x: 20, y: 90])
    }

    @Test("A mask partly outside the picture is clamped rather than trapping")
    func maskOutside() {
        let before = screen()
        let after = Redactor().apply(
            [Mask(rect: SceneRect(x: -50, y: -50, width: 120, height: 120), style: .solid)],
            to: before
        )
        #expect(after[x: 10, y: 10] != before[x: 10, y: 10])
        #expect(after.isWellFormed)
    }

    @Test("A mask entirely outside the picture changes nothing")
    func maskCompletelyOutside() {
        let before = screen()
        let after = Redactor().apply(
            [Mask(rect: SceneRect(x: 500, y: 500, width: 20, height: 20), style: .solid)],
            to: before
        )
        #expect(after.pixels == before.pixels)
    }

    @Test("No masks leave the picture as it was")
    func noMasks() {
        let before = screen()
        #expect(Redactor().apply([], to: before).pixels == before.pixels)
    }

    @Test("Masking is reproducible")
    func reproducible() {
        let before = screen()
        let masks = [Mask(rect: Self.secret, style: .pixelate)]
        #expect(isReproducible { Redactor().apply(masks, to: before).pixels })
    }
}

@Suite("Verifying a mask")
struct VerifyTests {

    private static let area = SceneRect(x: 20, y: 20, width: 40, height: 20)

    private func screen() -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 100, height: 60)
        for column in 0..<8 {
            screen.paint(
                SceneRect(x: 22 + Double(column) * 5, y: 22, width: 2, height: 16),
                color: .opaque(red: 200, green: 30, blue: 30)
            )
        }
        return screen.image
    }

    private var masks: [Mask] { [Mask(rect: Self.area, style: .solid)] }

    @Test("A picture with the mask applied passes")
    func passes() {
        let before = screen()
        let masked = Redactor().apply(masks, to: before)
        #expect(Redactor().verify(masks, original: before, masked: masked).isEmpty)
    }

    @Test("A picture that was never masked fails")
    func catchesAnUnmaskedExport() {
        let before = screen()
        let failures = Redactor().verify(masks, original: before, masked: before)
        #expect(failures.count == 1)
        #expect(failures.first?.rect == Self.area)
    }

    @Test("A mask applied somewhere else fails")
    func catchesAMisplacedMask() {
        let before = screen()
        let elsewhere = SceneRect(x: 20, y: 42, width: 40, height: 15)
        let masked = Redactor().apply([Mask(rect: elsewhere, style: .solid)], to: before)
        #expect(!Redactor().verify(masks, original: before, masked: masked).isEmpty)
    }

    @Test("An area that was already blank is not a failure")
    func blankArea() {
        let blank = SyntheticScreenshot(width: 100, height: 60).image
        let masked = Redactor().apply(masks, to: blank)
        #expect(Redactor().verify(masks, original: blank, masked: masked).isEmpty)
    }

    @Test("Pictures of different sizes are every mask failing")
    func mismatchedSizes() {
        let before = screen()
        let other = SyntheticScreenshot(width: 50, height: 30).image
        #expect(Redactor().verify(masks, original: before, masked: other).count == masks.count)
    }

    @Test("Verifying is reproducible")
    func reproducible() {
        let before = screen()
        #expect(isReproducible { Redactor().verify(masks, original: before, masked: before) })
    }
}
