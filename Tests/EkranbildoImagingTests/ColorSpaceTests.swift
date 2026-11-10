import CoreGraphics
import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoImaging
import Testing

@Suite("Colour spaces")
struct ColorSpaceTests {

    private func patches() -> SyntheticScreenshot {
        var screen = SyntheticScreenshot(
            width: 60, height: 20, background: .opaque(red: 0, green: 0, blue: 0))
        let colors: [ImageBuffer.Pixel] = [
            .opaque(red: 255, green: 0, blue: 0),
            .opaque(red: 0, green: 255, blue: 0),
            .opaque(red: 0, green: 0, blue: 255),
            .opaque(red: 255, green: 255, blue: 255),
            .opaque(red: 128, green: 128, blue: 128),
            .opaque(red: 18, green: 52, blue: 86),
        ]
        for (index, color) in colors.enumerated() {
            screen.paint(
                SceneRect(x: Double(index * 10), y: 0, width: 10, height: 20),
                color: color
            )
        }
        return screen
    }

    private static let patchCentres = Array(stride(from: 5, to: 60, by: 10))

    @Test("A colour survives the journey into the working space and back")
    func roundTripThroughWorkingSpace() throws {
        let original = patches().image
        let working = try ImageCodec.decode(
            try ImageCodec.encodePNG(original),
            into: .displayP3
        )
        let returned = try ImageCodec.decode(
            try ImageCodec.encodePNG(working.image),
            into: .sRGB
        )

        for x in Self.patchCentres {
            let before = original[x: x, y: 10]
            let after = returned.image[x: x, y: 10]
            #expect(
                channelsAgree(before, after, tolerance: Tolerances.roundTrip),
                "patch at \(x) went \(before) -> \(after)"
            )
        }
    }

    @Test("Converting is not relabelling")
    func conversionActuallyHappens() throws {
        let original = patches().image
        let working = try ImageCodec.decode(
            try ImageCodec.encodePNG(original),
            into: .displayP3
        )

        #expect(working.image.colorSpace == .displayP3)
        let red = working.image[x: 5, y: 10]
        #expect(red.red < ImageBuffer.Channel.maximum, "red was relabelled, not converted")
        #expect(red.green > 0 || red.blue > 0, "red was relabelled, not converted")
    }

    @Test("Neutral greys are unmoved by the conversion")
    func greysAreNeutral() throws {
        let working = try ImageCodec.decode(
            try ImageCodec.encodePNG(patches().image),
            into: .displayP3
        )
        for x in [35, 45] {
            let grey = working.image[x: x, y: 10]
            #expect(abs(Int(grey.red) - Int(grey.green)) <= Tolerances.channel)
            #expect(abs(Int(grey.green) - Int(grey.blue)) <= Tolerances.channel)
        }
    }

    @Test("The source colour space is reported")
    func sourceReported() throws {
        let decoded = try ImageCodec.decode(
            try ImageCodec.encodePNG(patches().image),
            into: .displayP3
        )
        #expect(!decoded.sourceColorSpace.isEmpty)
        #expect(decoded.sourceColorSpace.lowercased().contains("srgb"))
    }

    @Test("Decoding without saying where lands in the working space")
    func defaultDestination() throws {
        let decoded = try ImageCodec.decode(try ImageCodec.encodePNG(patches().image))
        #expect(decoded.colorSpace == CanonicalColorSpace.workingSpace)
    }

    @Test(
        "Linear light and encoded light are inverses",
        arguments: [0.0, 0.001, 0.04, 0.5, 0.9, 1.0]
    )
    func transferFunction(value: Double) {
        let there = TransferFunction.linearFromEncoded(value)
        #expect(approximatelyEqual(TransferFunction.encodedFromLinear(there), value, tolerance: 1e-9))
    }

    @Test("The transfer function is not a plain power law")
    func notAPowerLaw() {
        #expect(approximatelyEqual(TransferFunction.linearFromEncoded(0.02), 0.02 / 12.92, tolerance: 1e-12))
        #expect(TransferFunction.linearFromEncoded(0.5) < 0.5)
        #expect(TransferFunction.linearFromEncoded(0) == 0)
        #expect(TransferFunction.linearFromEncoded(1) == 1)
    }

    private func channelsAgree(
        _ a: ImageBuffer.Pixel,
        _ b: ImageBuffer.Pixel,
        tolerance: Int
    ) -> Bool {
        abs(Int(a.red) - Int(b.red)) <= tolerance
            && abs(Int(a.green) - Int(b.green)) <= tolerance
            && abs(Int(a.blue) - Int(b.blue)) <= tolerance
            && a.alpha == b.alpha
    }

    private enum Tolerances {
        static let roundTrip = 3
        static let channel = 1
    }
}
