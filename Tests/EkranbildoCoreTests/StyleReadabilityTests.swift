import EkranbildoContracts
@testable import EkranbildoCore
import Testing

@Suite("Style readability")
struct StyleReadabilityTests {

    private static let required: Double = 4.5

    @Test("The standard style's labels can be read")
    func standardLabelReads() {
        #expect(StyleTokens.standard.labelContrast >= Self.required)
    }

    @Test("The standard style's step numbers can be read")
    func standardBadgeReads() {
        #expect(StyleTokens.standard.badgeContrast >= Self.required)
    }

    @Test("A style whose label cannot be read says so")
    func unreadableStyleIsCaught() {
        var style = StyleTokens.standard
        style.labelPlateColor = Color(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
        #expect(style.labelContrast < Self.required)
        #expect(!style.isReadable)
    }

    @Test("The standard style is readable")
    func standardIsReadable() {
        #expect(StyleTokens.standard.isReadable)
    }

    @Test("A style whose step numbers cannot be read is not readable")
    func unreadableBadgeIsCaught() {
        var style = StyleTokens.standard
        style.badgeColor = Color(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)

        #expect(style.labelContrast >= Self.required)
        #expect(style.badgeContrast < Self.required)
        #expect(!style.isReadable)
    }

    @Test("A translucent plate is judged over what is behind it")
    func translucentPlate() {
        var style = StyleTokens.standard
        style.labelColor = Color(red: 1, green: 1, blue: 1, alpha: 1)
        style.labelPlateColor = Color(red: 0, green: 0, blue: 0, alpha: 0.1)

        #expect(style.labelContrast(over: Color(red: 1, green: 1, blue: 1, alpha: 1)) < Self.required)
        #expect(style.labelContrast(over: Color(red: 0, green: 0, blue: 0, alpha: 1)) >= Self.required)
    }

    @Test("The standard style can be read with any kind of colour vision", arguments: ColorVision.allCases)
    func standardReadsForEverybody(vision: ColorVision) {
        #expect(StyleTokens.standard.isReadable(seenWith: vision))
    }

    @Test("Red on green passes on contrast and fails when anybody looks at it")
    func redOnGreenIsCaught() {
        var style = StyleTokens.standard
        style.labelColor = Color(red: 0.86, green: 0.16, blue: 0.16, alpha: 1)
        style.labelPlateColor = Color(red: 0.16, green: 0.66, blue: 0.26, alpha: 1)

        #expect(style.labelContrast > 1.5)
        #expect(style.labelContrast(seenWith: .deuteranopia) < 1.5)
        #expect(!style.isReadable(seenWith: .deuteranopia))
    }

    @Test("A red label on white passes on contrast and fails without the middle cone")
    func redOnWhiteIsCaught() {
        var style = StyleTokens.standard
        style.labelColor = Color(red: 0.86, green: 0.16, blue: 0.16, alpha: 1)
        style.labelPlateColor = Color(red: 1, green: 1, blue: 1, alpha: 1)

        #expect(style.labelContrast >= Self.required)
        #expect(style.labelContrast(seenWith: .deuteranopia) < Self.required)
    }

    @Test("Black on white reads for everybody", arguments: ColorVision.allCases)
    func blackOnWhite(vision: ColorVision) {
        var style = StyleTokens.standard
        style.labelColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
        style.labelPlateColor = Color(red: 1, green: 1, blue: 1, alpha: 1)
        style.badgeTextColor = style.labelColor
        style.badgeColor = style.labelPlateColor

        #expect(style.labelContrast(seenWith: vision) > 15)
    }
}
