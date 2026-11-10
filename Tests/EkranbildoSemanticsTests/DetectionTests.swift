import EkranbildoContracts
import EkranbildoFixtures
import EkranbildoGeometry
@testable import EkranbildoSemantics
import EkranbildoTestKit
import Testing

@Suite("Edge map")
struct EdgeMapTests {

    @Test("A flat image has no edges")
    func flatImage() {
        let flat = SyntheticScreenshot(width: 32, height: 32).image
        let edges = EdgeMap(of: flat)
        for y in 0..<flat.height {
            for x in 0..<flat.width {
                #expect(edges[x: x, y: y] == 0)
            }
        }
    }

    @Test("A border between two colours registers as an edge")
    func borderIsAnEdge() {
        let screen = SceneLibrary.threeControls
        let edges = EdgeMap(of: screen.image)
        let button = screen.region(named: "primary button")!

        let onBorder = edges[x: Int(button.minX), y: Int(button.minY) + 10]
        let inside = edges[x: Int(button.minX) + 20, y: Int(button.minY) + 10]
        #expect(onBorder > inside)
        #expect(inside == 0)
    }

    @Test("Edge strength does not depend on which side the brighter colour is on")
    func edgesAreSymmetric() {
        var rising = SyntheticScreenshot(
            width: 32, height: 32, background: .opaque(red: 0, green: 0, blue: 0))
        rising.add(
            SceneRect(x: 16, y: 0, width: 16, height: 32),
            color: .opaque(red: 255, green: 255, blue: 255),
            named: "half"
        )
        var falling = SyntheticScreenshot(
            width: 32, height: 32, background: .opaque(red: 255, green: 255, blue: 255))
        falling.add(
            SceneRect(x: 16, y: 0, width: 16, height: 32),
            color: .opaque(red: 0, green: 0, blue: 0),
            named: "half"
        )
        let up = EdgeMap(of: rising.image)
        let down = EdgeMap(of: falling.image)
        #expect(approximatelyEqual(up[x: 16, y: 16], down[x: 16, y: 16], tolerance: 1e-9))
    }

    @Test(
        "Edge strength is the luminance difference across a boundary",
        arguments: [16, 64, 128, 255]
    )
    func strengthMatchesContrast(level: Int) {
        var screen = SyntheticScreenshot(
            width: 32, height: 32, background: .opaque(red: 0, green: 0, blue: 0))
        let bright = ImageBuffer.Pixel.opaque(
            red: UInt8(level), green: UInt8(level), blue: UInt8(level))
        screen.paint(SceneRect(x: 16, y: 0, width: 16, height: 32), color: bright)

        let edges = EdgeMap(of: screen.image)
        let contrast = bright.luminance
        #expect(approximatelyEqual(edges[x: 15, y: 16], contrast, tolerance: 1e-9))
        #expect(approximatelyEqual(edges[x: 16, y: 16], contrast, tolerance: 1e-9))
    }

    @Test("Edge strength stays within zero to one")
    func normalised() {
        var screen = SyntheticScreenshot(
            width: 32, height: 32, background: .opaque(red: 0, green: 0, blue: 0))
        screen.paint(
            SceneRect(x: 16, y: 16, width: 16, height: 16),
            color: .opaque(red: 255, green: 255, blue: 255)
        )
        let edges = EdgeMap(of: screen.image)
        for y in 0..<32 {
            for x in 0..<32 {
                #expect(edges[x: x, y: y] >= 0)
                #expect(edges[x: x, y: y] <= 1)
            }
        }
    }

    @Test("An empty image produces an empty map rather than failing")
    func emptyImage() {
        let edges = EdgeMap(of: ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: []))
        #expect(edges[x: 0, y: 0] == 0)
    }

    @Test("The same image always produces the same map")
    func reproducible() {
        let image = SceneLibrary.threeControls.image
        #expect(isReproducible { EdgeMap(of: image).values })
    }
}

@Suite("Region detection")
struct RegionDetectionTests {

    @Test("A click inside a control snaps to that control")
    func snapsToTheControl() throws {
        let screen = SceneLibrary.threeControls
        let detector = RegionDetector(image: screen.image)
        let button = try #require(screen.region(named: "primary button"))

        let snapped = try #require(
            detector.region(containing: ScenePoint(x: button.minX + 10, y: button.minY + 10))
        )
        #expect(approximatelyEqual(snapped.minX, button.minX, tolerance: 1))
        #expect(approximatelyEqual(snapped.minY, button.minY, tolerance: 1))
        #expect(approximatelyEqual(snapped.width, button.width, tolerance: 1))
        #expect(approximatelyEqual(snapped.height, button.height, tolerance: 1))
    }

    @Test("Each control is found from a click anywhere inside it")
    func everyControlIsFound() throws {
        let screen = SceneLibrary.threeControls
        let detector = RegionDetector(image: screen.image)

        for region in screen.regions {
            let inside = ScenePoint(
                x: region.rect.minX + region.rect.width / 2,
                y: region.rect.minY + region.rect.height / 2
            )
            let snapped = try #require(detector.region(containing: inside), "\(region.name) not found")
            #expect(
                approximatelyEqual(snapped.width, region.rect.width, tolerance: 1),
                "\(region.name) came back the wrong width"
            )
        }
    }

    @Test("A click on the background snaps to the background, not to a control")
    func clickOnBackground() throws {
        let screen = SceneLibrary.threeControls
        let detector = RegionDetector(image: screen.image)
        let snapped = try #require(detector.region(containing: ScenePoint(x: 180, y: 110)))
        #expect(snapped.width > 100)
    }

    @Test("A click outside the image finds nothing")
    func clickOutside() {
        let detector = RegionDetector(image: SceneLibrary.threeControls.image)
        #expect(detector.region(containing: ScenePoint(x: -5, y: -5)) == nil)
        #expect(detector.region(containing: ScenePoint(x: 500, y: 500)) == nil)
    }

    @Test("A gradient fill does not split the control it fills")
    func toleratesGradients() throws {
        var screen = SyntheticScreenshot(width: 100, height: 60)
        screen.add(
            SceneRect(x: 10, y: 10, width: 60, height: 30),
            color: .opaque(red: 100, green: 140, blue: 200),
            named: "button"
        )
        for row in 0..<30 {
            let shade = UInt8(20 * row / 30)
            screen.paint(
                SceneRect(x: 10, y: 10 + Double(row), width: 60, height: 1),
                color: .opaque(red: 100 + shade, green: 140 + shade, blue: 200 + shade)
            )
        }

        let detector = RegionDetector(image: screen.image)
        let snapped = try #require(detector.region(containing: ScenePoint(x: 40, y: 20)))
        #expect(approximatelyEqual(snapped.height, 30, tolerance: 1))
        #expect(approximatelyEqual(snapped.width, 60, tolerance: 1))
    }

    @Test("A long drift stops the fill even when every step is small")
    func stopsOnAccumulatedDrift() throws {
        let width = 200
        var screen = SyntheticScreenshot(width: width, height: 40)
        for column in 0..<width {
            let shade = UInt8(min(255, column))
            screen.paint(
                SceneRect(x: Double(column), y: 0, width: 1, height: 40),
                color: .opaque(red: shade, green: shade, blue: shade)
            )
        }

        let detector = RegionDetector(image: screen.image)
        let region = try #require(detector.region(containing: ScenePoint(x: 2, y: 20)))
        #expect(
            region.width < Double(width),
            "a fill that crossed the whole ramp has no ceiling on how far it drifts"
        )
        let reach = RegionDetector.Defaults.globalTolerance * Double(ImageBuffer.Channel.maximum)
        #expect(approximatelyEqual(region.width, reach, tolerance: reach * 0.2))
    }

    @Test("Regions touching only at a corner stay separate")
    func doesNotLeakThroughCorners() throws {
        var screen = SyntheticScreenshot(width: 80, height: 80)
        let control = ImageBuffer.Pixel.opaque(red: 40, green: 110, blue: 220)
        screen.paint(SceneRect(x: 0, y: 0, width: 30, height: 30), color: control)
        screen.paint(SceneRect(x: 30, y: 30, width: 30, height: 30), color: control)

        let detector = RegionDetector(image: screen.image)
        let region = try #require(detector.region(containing: ScenePoint(x: 10, y: 10)))
        #expect(region.width == 30, "the fill crossed the corner into the other block")
        #expect(region.height == 30)
    }

    @Test("Detection is reproducible")
    func reproducible() {
        let detector = RegionDetector(image: SceneLibrary.threeControls.image)
        #expect(isReproducible { detector.region(containing: ScenePoint(x: 40, y: 30)) })
    }
}

@Suite("Element detection")
struct ElementDetectionTests {

    @Test("Every drawn control turns up as an element")
    func findsEveryControl() {
        let screen = SceneLibrary.threeControls
        let elements = ElementDetector().detect(in: screen.image)

        for region in screen.regions {
            let matched = elements.contains { element in
                Geo.overlapArea(element.rect.raw, region.rect.raw) > region.rect.raw.area / 2
            }
            #expect(matched, "\(region.name) was not detected")
        }
    }

    @Test("Elements are ordered largest first, so the coarsest target comes first")
    func orderedBySize() {
        let elements = ElementDetector().detect(in: SceneLibrary.threeControls.image)
        let areas = elements.map(\.rect.raw.area)
        #expect(areas == areas.sorted(by: >))
    }

    @Test("Detection of an empty image finds nothing rather than failing")
    func emptyImage() {
        let elements = ElementDetector().detect(
            in: ImageBuffer(width: 0, height: 0, colorSpace: .sRGB, pixels: [])
        )
        #expect(elements.isEmpty)
    }

    @Test("Detection is reproducible")
    func reproducible() {
        let image = SceneLibrary.threeControls.image
        #expect(isReproducible { ElementDetector().detect(in: image).map(\.rect) })
    }
}

@Suite("Element size floor")
struct ElementSizeFloorTests {

    @Test("A hairline is not an element, however long it is")
    func rejectsHairlines() {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        let line = SceneRect(x: 20, y: 60, width: 160, height: 1)
        screen.paint(line, color: .opaque(red: 210, green: 210, blue: 214))

        let elements = ElementDetector().detect(in: screen.image)
        #expect(!elements.contains { $0.rect.raw.height <= line.raw.height })
    }

    @Test("A small round control is an element, however little area it has")
    func keepsSmallControls() throws {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        let dot = SceneRect(x: 20, y: 20, width: 12, height: 12)
        screen.add(dot, color: .opaque(red: 255, green: 95, blue: 87), named: "close button")

        let elements = ElementDetector().detect(in: screen.image)
        let best = elements.map { Geo.intersectionOverUnion($0.rect.raw, dot.raw) }.max() ?? 0
        #expect(best > 0.9, "the control was not found: \(ScreenElement.listing(elements))")
    }

    @Test("Speckle is still rejected")
    func rejectsSpeckle() {
        var screen = SyntheticScreenshot(width: 200, height: 120)
        for offset in 0..<4 {
            screen.paint(
                SceneRect(x: Double(20 + offset * 8), y: 20, width: 2, height: 2),
                color: .opaque(red: 0, green: 0, blue: 0)
            )
        }
        #expect(ElementDetector().detect(in: screen.image).count == 1)
    }
}
