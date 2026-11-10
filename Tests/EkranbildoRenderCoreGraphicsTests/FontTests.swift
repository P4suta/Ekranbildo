import CoreText
import EkranbildoContracts
import EkranbildoCore
import EkranbildoImaging
@testable import EkranbildoRenderCoreGraphics
import Testing

@Suite("Fonts")
struct FontTests {

    @Test("A face that is installed is the one used")
    func installedFace() {
        let resolved = CoreGraphicsRenderer.resolveFont(
            FontSpec(family: "Helvetica", size: 14))
        #expect(!resolved.substituted)
        #expect(resolved.family.caseInsensitiveCompare("Helvetica") == .orderedSame)
    }

    @Test("A face that is not installed falls back to a named one")
    func namedFallback() {
        let resolved = CoreGraphicsRenderer.resolveFont(
            FontSpec(family: "A Face Nobody Has Installed", size: 14))
        #expect(resolved.substituted)
        #expect(
            resolved.family.caseInsensitiveCompare(CoreGraphicsRenderer.Fonts.fallbackFamily)
                == .orderedSame
        )
    }

    @Test("The named fallback is installed")
    func fallbackExists() {
        let resolved = CoreGraphicsRenderer.resolveFont(
            FontSpec(family: CoreGraphicsRenderer.Fonts.fallbackFamily, size: 14))
        #expect(!resolved.substituted)
    }

    @Test("A substitution says which face was used instead")
    func warningNamesTheFace() throws {
        let list = DrawList(
            canvas: SceneRect(x: 0, y: 0, width: 200, height: 60),
            colorSpace: .sRGB,
            commands: [
                .text(
                    TextRun(
                        text: "Label",
                        font: FontSpec(family: "A Face Nobody Has Installed", size: 14),
                        baselineOrigin: ScenePoint(x: 10, y: 30),
                        paint: .solid(Color(red: 0, green: 0, blue: 0, alpha: 1)),
                        metrics: TextMetrics(width: 40, ascent: 12, descent: 4)
                    )
                )
            ]
        )
        let result = try CoreGraphicsRenderer().render(list, scale: 1)
        let warning = try #require(
            result.warnings.first { $0.code == RenderWarning.fontSubstituted })
        #expect(warning.detail.contains(CoreGraphicsRenderer.Fonts.fallbackFamily))
        #expect(warning.detail.contains("A Face Nobody Has Installed"))
    }

    @Test("The intended face is either installed or reported as missing")
    func intendedFace() {
        let resolved = CoreGraphicsRenderer.resolveFont(StyleTokens.standard.labelFont)
        if resolved.substituted {
            #expect(
                resolved.family.caseInsensitiveCompare(CoreGraphicsRenderer.Fonts.fallbackFamily)
                    == .orderedSame,
                """
                The intended label face is not installed and the fallback is not \
                the named one. Pixel goldens are not meaningful until one of \
                those is true.
                """
            )
        }
    }
}
