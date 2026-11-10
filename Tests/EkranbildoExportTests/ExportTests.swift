import EkranbildoContracts
@testable import EkranbildoExport
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoTestKit
import Testing

@Suite("Export")
struct ExportTests {

    private func picture() -> ImageBuffer {
        var screen = SyntheticScreenshot(width: 120, height: 80)
        screen.paint(
            SceneRect(x: 20, y: 20, width: 60, height: 30),
            color: .opaque(red: 40, green: 120, blue: 220)
        )
        return screen.image
    }

    @Test("Every format produces something a reader recognises", arguments: ExportFormat.allCases)
    func producesItsFormat(format: ExportFormat) throws {
        let bytes = try Exporter().export(picture(), as: format)
        #expect(!bytes.isEmpty)
        #expect(format.matchesSignature(of: bytes), "\(format) produced something else")
    }

    @Test("A picture exported as an image comes back the same size")
    func imageSize() throws {
        let exported = try Exporter().export(picture(), as: .png)
        let decoded = try ImageCodec.decode(exported, into: picture().colorSpace).image
        #expect(decoded.width == 120)
        #expect(decoded.height == 80)
    }

    @Test("Colours survive being exported as an image")
    func imageColours() throws {
        let original = picture()
        let decoded = try ImageCodec.decode(
            try Exporter().export(original, as: .png),
            into: original.colorSpace
        ).image
        #expect(decoded[x: 40, y: 30] == original[x: 40, y: 30])
    }

    @Test(
        "Nothing is written that says where, when, or on what",
        arguments: [ExportFormat.png, .jpeg]
    )
    func noIdentifyingMetadata(format: ExportFormat) throws {
        let bytes = try Exporter().export(picture(), as: format)
        let found = Exporter.identifyingContent(in: try ImageCodec.properties(of: bytes))
        #expect(found.isEmpty, "the file carries \(found)")
    }

    @Test("A page says nothing about when it was made")
    func pageHasNoTimestamp() throws {
        let bytes = try Exporter().export(picture(), as: .pdf)
        let marker = Array("/CreationDate (".utf8)
        guard let at = bytes.firstIndex(of: marker) else { return }
        let value = bytes[(at + marker.count)...].prefix { $0 != UInt8(ascii: ")") }
        #expect(
            value.allSatisfy { $0 == UInt8(ascii: "0") },
            "the page says when it was made"
        )
    }

    @Test("A picture with something to hide is exported as pixels, not as text")
    func noSelectableText() throws {
        let bytes = try Exporter().export(picture(), as: .pdf)
        #expect(!Exporter.containsSelectableText(bytes), "the text under the mask is still there")
    }

    @Test("A file too short to have a signature does not match one", arguments: ExportFormat.allCases)
    func shortFile(format: ExportFormat) {
        #expect(!format.matchesSignature(of: []))
        #expect(!format.matchesSignature(of: [0x89]))
    }

    @Test("An empty picture is refused rather than exported")
    func emptyPicture() {
        let nothing = ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: [])
        #expect(throws: ExportError.self) {
            try Exporter().export(nothing, as: .png)
        }
    }

    @Test("Exporting is reproducible", arguments: ExportFormat.allCases)
    func reproducible(format: ExportFormat) {
        let original = picture()
        #expect(isReproducible { try? Exporter().export(original, as: format) })
    }
}
