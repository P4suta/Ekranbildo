@testable import EkranbildoContracts
import Foundation
import Testing

@Suite("Paint decoding")
struct PaintDecodingTests {

    private func decoded<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    @Test(
        "A colour out of range is brought into range rather than carried",
        arguments: [
            ("5", 1.0), ("-2", 0.0), ("0.5", 0.5),
        ]
    )
    func clampsWhenDecoding(written: String, expected: Double) throws {
        let color: Color = try decoded(
            #"{"red": \#(written), "green": 0, "blue": 0, "alpha": 1}"#)
        #expect(color.red == expected)
    }

    @Test("A colour whose component is not a number is refused")
    func refusesWhatIsNotANumber() {
        #expect(throws: (any Error).self) {
            let _: Color = try decoded(
                #"{"red": "quite red", "green": 0, "blue": 0, "alpha": 1}"#)
        }
    }

    @Test("A colour with no alpha is opaque")
    func opaqueByDefault() throws {
        let color: Color = try decoded(#"{"red": 1, "green": 0, "blue": 0}"#)
        #expect(color.alpha == 1)
    }

    @Test("A colour survives being saved and opened")
    func colorRoundTrips() throws {
        let color = Color(red: 0.25, green: 0.5, blue: 0.75, alpha: 0.5)
        let data = try JSONEncoder().encode(color)
        #expect(try JSONDecoder().decode(Color.self, from: data) == color)
    }

    @Test("A font written before a field existed still opens")
    func opensAnOldFont() throws {
        let font: FontSpec = try decoded(#"{"family": "Inter", "size": 14}"#)
        #expect(font.family == "Inter")
        #expect(font.weight == .regular)
        #expect(font.italic == false)
    }

    @Test("A font with no family is refused")
    func refusesAFontWithNoFamily() {
        #expect(throws: (any Error).self) {
            let _: FontSpec = try decoded(#"{"size": 14}"#)
        }
    }

    @Test("A font survives being saved and opened")
    func fontRoundTrips() throws {
        let font = FontSpec(family: "Inter", size: 14, weight: .bold, italic: true)
        let data = try JSONEncoder().encode(font)
        #expect(try JSONDecoder().decode(FontSpec.self, from: data) == font)
    }
}
