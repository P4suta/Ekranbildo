import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoSemantics
import EkranbildoTestKit
import Testing

@Suite("Detection quality")
struct DetectionQualityTests {

    private func bestMatch(for truth: SceneRect, in elements: [ScreenElement]) -> Double {
        elements.map { Geo.intersectionOverUnion($0.rect.raw, truth.raw) }.max() ?? 0
    }

    @Test("Every element in a layered interface is found closely")
    func layeredInterface() {
        let screen = SceneLibrary.applicationWindow
        let elements = ElementDetector().detect(in: screen.image)

        for region in screen.regions {
            let ratio = bestMatch(for: region.rect, in: elements)
            #expect(
                ratio > Thresholds.close,
                "\(region.name) matched at only \(ratio)"
            )
        }
    }

    private enum Thresholds {
        static let close = 0.9
        static let meanAcceptable = 0.95
    }

    @Test("The average match across a screen holds its level")
    func averageQuality() {
        let screen = SceneLibrary.applicationWindow
        let elements = ElementDetector().detect(in: screen.image)
        let ratios = screen.regions.map { bestMatch(for: $0.rect, in: elements) }
        let mean = ratios.reduce(0, +) / Double(ratios.count)
        #expect(mean >= Thresholds.meanAcceptable, "mean overlap fell to \(mean)")
    }

    @Test("A near-white field is kept separate from a near-white panel")
    func lowContrastBoundary() {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        screen.add(
            SceneRect(x: 10, y: 10, width: 180, height: 100),
            color: .opaque(red: 250, green: 250, blue: 252),
            named: "panel"
        )
        screen.add(
            SceneRect(x: 30, y: 40, width: 140, height: 28),
            color: .opaque(red: 255, green: 255, blue: 255),
            named: "field"
        )

        let detector = RegionDetector(image: screen.image)
        let snapped = detector.region(containing: ScenePoint(x: 100, y: 54))
        #expect(snapped != nil)
        #expect(approximatelyEqual(snapped?.width ?? 0, 140, tolerance: 1))
    }

    @Test("A long gradient does not swallow the whole image")
    func gradientIsBounded() {
        var screen = SyntheticScreenshot(
            width: 200, height: 40, background: .opaque(red: 0, green: 0, blue: 0))
        for step in 0..<40 {
            screen.paint(
                SceneRect(x: Double(step) * 5, y: 0, width: 5, height: 40),
                color: .opaque(
                    red: UInt8(step * 5),
                    green: UInt8(step * 5),
                    blue: UInt8(step * 5)
                )
            )
        }

        let detector = RegionDetector(image: screen.image)
        let snapped = detector.region(containing: ScenePoint(x: 100, y: 20))
        #expect(snapped != nil)
        #expect((snapped?.width ?? 0) < 200, "the fill ran the whole width of the image")
    }

    @Test("Quality measurement is reproducible")
    func reproducible() {
        let image = SceneLibrary.applicationWindow.image
        #expect(isReproducible { ElementDetector().detect(in: image).map(\.rect) })
    }
}
