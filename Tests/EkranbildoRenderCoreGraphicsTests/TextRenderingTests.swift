import EkranbildoContracts
import EkranbildoImaging
@testable import EkranbildoRenderCoreGraphics
import EkranbildoTestKit
import Testing

@Suite("Text rendering")
struct TextRenderingTests {
    private let canvas = SceneRect(x: 0, y: 0, width: 120, height: 40)

    private func run(_ text: String, family: String = "Helvetica") -> TextRun {
        TextRun(
            text: text,
            font: FontSpec(family: family, size: 20, weight: .regular),
            baselineOrigin: ScenePoint(x: 10, y: 28),
            paint: .solid(Color(red: 0, green: 0, blue: 0, alpha: 1)),
            metrics: TextMetrics(width: 60, ascent: 16, descent: 4)
        )
    }

    private func render(_ commands: [DrawCommand]) throws -> RenderResult {
        try CoreGraphicsRenderer().render(
            DrawList(canvas: canvas, colorSpace: .sRGB, commands: commands),
            scale: 1
        )
    }

    @Test("Glyphs actually mark the bitmap")
    func textIsDrawn() throws {
        let blank = try render([])
        let drawn = try render([.text(run("HHHH"))])

        func inkedPixels(_ bitmap: RenderedBitmap) -> Int {
            var count = 0
            for y in 0..<bitmap.height where y >= 0 {
                for x in 0..<bitmap.width where bitmap.pixel(x: x, y: y).alpha > 0 {
                    count += 1
                }
            }
            return count
        }
        #expect(inkedPixels(blank.bitmap) == 0)
        #expect(inkedPixels(drawn.bitmap) > 0)
    }

    @Test("Text sits on the baseline it was given")
    func baselinePosition() throws {
        let result = try render([.text(run("H"))])
        var inkedAboveBaseline = false
        for y in 12..<27 where result.bitmap.pixel(x: 12, y: y).alpha > 0 {
            inkedAboveBaseline = true
        }
        #expect(inkedAboveBaseline)
        #expect(result.bitmap.pixel(x: 12, y: 38).alpha == 0)
    }

    @Test("Empty text draws nothing")
    func emptyText() throws {
        let result = try render([.text(run(""))])
        #expect(result.bitmap.pixel(x: 12, y: 20).alpha == 0)
        #expect(result.warnings.isEmpty)
    }

    @Test("Substituting a missing font is reported")
    func missingFontIsReported() throws {
        let result = try render([.text(run("Save", family: "Ekranbildo Sans Which Does Not Exist"))])
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.code == RenderWarning.fontSubstituted)
        #expect(result.warnings.first?.detail.contains("Ekranbildo Sans Which Does Not Exist") == true)
    }

    @Test("The same substitution is reported once however many runs use it")
    func warningsAreDeduplicated() throws {
        let missing = "Ekranbildo Sans Which Does Not Exist"
        let result = try render([
            .text(run("one", family: missing)),
            .text(run("two", family: missing)),
            .text(run("three", family: missing)),
        ])
        #expect(result.warnings.count == 1)
    }

    @Test("Different substitutions are reported separately")
    func distinctWarningsAreKept() throws {
        let result = try render([
            .text(run("one", family: "Missing Family One")),
            .text(run("two", family: "Missing Family Two")),
        ])
        #expect(result.warnings.count == 2)
    }

    @Test("An available font produces no warning")
    func availableFontIsNotReported() throws {
        #expect(try render([.text(run("Save", family: "Helvetica"))]).warnings.isEmpty)
    }

    @Test("Rendering the same text twice produces identical pixels")
    func reproducible() throws {
        #expect(try isReproducible { try render([.text(run("Save"))]).bitmap.pixels })
    }
}
