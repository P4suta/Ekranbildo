@testable import EkranbildoCore
import Foundation
import Testing

@Suite("Style tokens")
struct StyleTokensTests {

    private static let ancient = """
        {
          "tipGap": 6,
          "leaderWidth": 2.5,
          "leaderColor": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
          "arrowheadLength": 12,
          "arrowheadHalfWidth": 5,
          "labelFont": {"family": "Inter", "size": 14, "weight": "semibold"},
          "labelColor": {"red": 1, "green": 1, "blue": 1, "alpha": 1},
          "labelPlateColor": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
          "labelPlateCornerRadius": 6,
          "labelPaddingHorizontal": 10,
          "labelPaddingVertical": 6,
          "labelMinimumGap": 8
        }
        """

    private func decoded(_ json: String) throws -> StyleTokens {
        try JSONDecoder().decode(StyleTokens.self, from: Data(json.utf8))
    }

    @Test("A style written before a token existed still opens")
    func opensAnOldStyle() throws {
        let style = try decoded(Self.ancient)
        #expect(style.tipGap == 6)
        #expect(style.badgeDiameter == StyleTokens.Standard.badgeDiameter)
        #expect(style.cursorSize == StyleTokens.Standard.cursorSize)
    }

    @Test("A style written by a later version still opens")
    func opensANewerStyle() throws {
        let style = try decoded(
            """
            {"tipGap": 7, "somethingAddedLater": {"nested": [1, 2, 3]}}
            """)
        #expect(style.tipGap == 7)
    }

    @Test("A style of nothing at all is the standard one")
    func opensAnEmptyStyle() throws {
        #expect(try decoded("{}") == .standard)
    }

    @Test("A style survives being saved and opened")
    func roundTrips() throws {
        var style = StyleTokens.standard
        style.cursorSize = 31
        style.badgeDiameter = 19

        let data = try JSONEncoder().encode(style)
        #expect(try JSONDecoder().decode(StyleTokens.self, from: data) == style)
    }

    @Test("A token of the wrong kind is refused rather than guessed at")
    func refusesTheWrongKind() {
        #expect(throws: (any Error).self) {
            try decoded(#"{"tipGap": "quite a lot"}"#)
        }
    }
}
