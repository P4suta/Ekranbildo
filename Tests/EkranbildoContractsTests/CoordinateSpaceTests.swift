@testable import EkranbildoContracts
import EkranbildoGeometry
import Testing

@Suite("Coordinate spaces")
struct CoordinateSpaceTests {

    private let retina = DisplayGeometry(
        displayID: 1,
        bounds: Rect(x: 0, y: 0, width: 1_512, height: 982),
        backingScale: 2
    )
    private let external = DisplayGeometry(
        displayID: 2,
        bounds: Rect(x: -1_920, y: -200, width: 1_920, height: 1_080),
        backingScale: 1
    )

    @Test("Pixel size follows the backing scale")
    func pixelSize() {
        #expect(retina.pixelWidth == 3_024)
        #expect(retina.pixelHeight == 1_964)
        #expect(external.pixelWidth == 1_920)
        #expect(external.pixelHeight == 1_080)
    }

    @Test("Screen points convert to display pixels through the origin and the scale")
    func screenToDisplayPixel() {
        let point = ScreenPoint(x: 100, y: 50)
        #expect(retina.displayPixel(of: point) == DisplayPixel(x: 200, y: 100))
    }

    @Test("Displays placed left of and above the primary produce negative screen coordinates")
    func negativeOrigins() {
        let point = ScreenPoint(x: -1_920, y: -200)
        #expect(external.displayPixel(of: point) == DisplayPixel(x: 0, y: 0))
        #expect(external.contains(point))
        #expect(!retina.contains(point))
    }

    @Test("Screen to display pixel round-trips")
    func displayPixelRoundTrip() {
        var generator = SplitMix64(seed: 11)
        for display in [retina, external] {
            for _ in 0..<200 {
                let point = ScreenPoint(
                    x: display.bounds.minX + Double(generator.next() % 1_000) / 4,
                    y: display.bounds.minY + Double(generator.next() % 900) / 4
                )
                let restored = display.screenPoint(of: display.displayPixel(of: point))
                #expect(approximatelyEqual(restored.raw.x, point.raw.x))
                #expect(approximatelyEqual(restored.raw.y, point.raw.y))
            }
        }
    }

    private var regionCapture: CaptureGeometry {
        CaptureGeometry(
            display: retina,
            regionInScreen: Rect(x: 200, y: 100, width: 400, height: 300)
        )
    }

    @Test("A capture records its own pixel dimensions")
    func capturePixelSize() {
        #expect(regionCapture.pixelWidth == 800)
        #expect(regionCapture.pixelHeight == 600)
    }

    @Test("The captured region maps onto the scene origin")
    func regionOriginMapsToSceneOrigin() {
        let topLeft = ScreenPoint(x: 200, y: 100)
        #expect(regionCapture.scenePoint(of: topLeft) == ScenePoint(x: 0, y: 0))
    }

    @Test("Scene coordinates do not depend on the backing scale")
    func sceneSpaceIsScaleIndependent() {
        let region = Rect(x: 200, y: 100, width: 400, height: 300)
        let atOneX = CaptureGeometry(
            display: DisplayGeometry(displayID: 3, bounds: retina.bounds, backingScale: 1),
            regionInScreen: region
        )
        let atTwoX = CaptureGeometry(display: retina, regionInScreen: region)

        let sample = ScreenPoint(x: 350, y: 220)
        #expect(atOneX.scenePoint(of: sample) == atTwoX.scenePoint(of: sample))
        #expect(atOneX.sceneSize == atTwoX.sceneSize)
        #expect(atOneX.pixelWidth == 400)
        #expect(atTwoX.pixelWidth == 800)
    }

    @Test("Scene points convert to image pixels through the backing scale")
    func sceneToImagePixel() {
        #expect(regionCapture.imagePixel(of: ScenePoint(x: 10, y: 20)) == ImagePixel(x: 20, y: 40))
    }

    @Test("Scene and image pixel coordinates round-trip")
    func sceneImageRoundTrip() {
        var generator = SplitMix64(seed: 23)
        let capture = regionCapture
        for _ in 0..<500 {
            let point = ScenePoint(
                x: Double(generator.next() % 4_000) / 10,
                y: Double(generator.next() % 3_000) / 10
            )
            let restored = capture.scenePoint(of: capture.imagePixel(of: point))
            #expect(approximatelyEqual(restored.raw.x, point.raw.x))
            #expect(approximatelyEqual(restored.raw.y, point.raw.y))
        }
    }

    @Test("Screen and scene coordinates round-trip")
    func screenSceneRoundTrip() {
        var generator = SplitMix64(seed: 31)
        let capture = regionCapture
        for _ in 0..<500 {
            let point = ScreenPoint(
                x: Double(generator.next() % 6_000) / 4 - 500,
                y: Double(generator.next() % 4_000) / 4 - 500
            )
            let restored = capture.screenPoint(of: capture.scenePoint(of: point))
            #expect(approximatelyEqual(restored.raw.x, point.raw.x))
            #expect(approximatelyEqual(restored.raw.y, point.raw.y))
        }
    }

    @Test("Rectangles convert as a whole")
    func rectangleConversion() {
        let capture = regionCapture
        let screenRect = ScreenRect(x: 300, y: 200, width: 100, height: 50)
        let sceneRect = capture.sceneRect(of: screenRect)
        #expect(sceneRect == SceneRect(x: 100, y: 100, width: 100, height: 50))
        #expect(capture.imageRect(of: sceneRect) == ImageRect(x: 200, y: 200, width: 200, height: 100))
    }

    @Test("AppKit coordinates flip about the primary display height")
    func appKitFlip() {
        let primaryHeight = 982.0
        let flipped = AppKitCoordinates.screenRect(
            fromAppKitRect: Rect(x: 10, y: 0, width: 200, height: 100),
            primaryDisplayHeight: primaryHeight
        )
        #expect(flipped == ScreenRect(x: 10, y: 882, width: 200, height: 100))
    }

    @Test("The AppKit flip is its own inverse")
    func appKitFlipRoundTrip() {
        var generator = SplitMix64(seed: 47)
        let primaryHeight = 1_080.0
        for _ in 0..<300 {
            let rect = Rect(
                x: Double(generator.next() % 4_000) / 2 - 1_000,
                y: Double(generator.next() % 4_000) / 2 - 1_000,
                width: Double(generator.next() % 2_000) / 2,
                height: Double(generator.next() % 2_000) / 2
            )
            let there = AppKitCoordinates.screenRect(
                fromAppKitRect: rect,
                primaryDisplayHeight: primaryHeight
            )
            let back = AppKitCoordinates.appKitRect(
                fromScreenRect: there,
                primaryDisplayHeight: primaryHeight
            )
            #expect(approximatelyEqual(back.minX, rect.minX))
            #expect(approximatelyEqual(back.minY, rect.minY))
            #expect(approximatelyEqual(back.width, rect.width))
            #expect(approximatelyEqual(back.height, rect.height))
        }
    }
}

@Suite("Coordinate space labelling")
struct CoordinateSpaceLabellingTests {

    @Test("A point renders with the name of its space")
    func pointLabelling() {
        #expect(ScenePoint(x: 1.5, y: 2).canonicalText == "scene[1.500 2.000]")
        #expect(ScreenPoint(x: -3, y: 4).canonicalText == "screen[-3.000 4.000]")
        #expect(ImagePixel(x: 0, y: 0).canonicalText == "imagePixel[0.000 0.000]")
        #expect(DisplayPixel(x: 8, y: 9).canonicalText == "displayPixel[8.000 9.000]")
    }

    @Test("A rectangle renders with the name of its space")
    func rectLabelling() {
        #expect(
            SceneRect(x: 1, y: 2, width: 3, height: 4).canonicalText == "scene[1.000 2.000 3.000 4.000]"
        )
    }

    @Test("The space name is available without an instance")
    func staticName() {
        #expect(ScenePoint.spaceName == "scene")
        #expect(ScreenRect.spaceName == "screen")
    }
}
