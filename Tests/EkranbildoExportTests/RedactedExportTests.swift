import EkranbildoContracts
@testable import EkranbildoExport
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoRedaction
import Testing

@Suite("Exporting something masked")
struct RedactedExportTests {

    private static let secret = SceneRect(x: 20, y: 20, width: 80, height: 20)

    private func picture() -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 140, height: 70)
        for column in 0..<10 {
            screen.paint(
                SceneRect(x: 22 + Double(column) * 8, y: 22, width: 3, height: 16),
                color: .opaque(red: 10, green: 10, blue: 10)
            )
        }
        return screen.image
    }

    private var masks: [Mask] { [Mask(rect: Self.secret, style: .pixelate)] }

    @Test(
        "What was under a mask is not in the exported file",
        arguments: [ExportFormat.png, .jpeg]
    )
    func maskSurvivesExport(format: ExportFormat) throws {
        let original = picture()
        let covered = Redactor().apply(masks, to: original)
        let exported = try Exporter().export(covered, as: format)

        let readBack = try Self.pixels(of: exported, like: original)
        var recovered = 0
        for y in 20..<40 {
            for x in 20..<100 where readBack[x: x, y: y] == original[x: x, y: y] {
                recovered += 1
            }
        }
        let area = 20 * 80
        #expect(
            recovered < area / 2,
            "\(recovered) of \(area) pixels under the mask came back unchanged"
        )
    }

    @Test("A page carries no text at all")
    func pageHasNoText() throws {
        let covered = Redactor().apply(masks, to: picture())
        let page = try Exporter().export(covered, as: .pdf)
        #expect(!Exporter.containsSelectableText(page))
    }

    @Test("Everything outside the mask survives the journey")
    func restSurvives() throws {
        let original = picture()
        let covered = Redactor().apply(masks, to: original)
        let readBack = try Self.pixels(
            of: try Exporter().export(covered, as: .png), like: original)

        for y in 50..<70 {
            for x in 0..<140 {
                #expect(readBack[x: x, y: y] == original[x: x, y: y], "\(x),\(y) changed")
            }
        }
    }

    private static func pixels(of bytes: [UInt8], like original: ImageBuffer) throws -> ImageBuffer {
        try ImageCodec.decode(bytes, into: original.colorSpace).image
    }
}
