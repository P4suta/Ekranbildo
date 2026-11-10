@testable import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("Window stack")
struct WindowStackTests {

    private func window(
        _ id: UInt32,
        _ rect: Rect,
        layer: Int = 0,
        onScreen: Bool = true,
        title: String? = nil,
        app: String = "Test"
    ) -> WindowDescriptor {
        WindowDescriptor(
            id: WindowID(id),
            title: title,
            applicationName: app,
            bundleIdentifier: "test.\(app)",
            frame: ScreenRect(rect),
            isOnScreen: onScreen,
            layer: layer
        )
    }

    private func overlapping() -> WindowStack {
        WindowStack(windows: [
            window(1, Rect(x: 100, y: 100, width: 400, height: 300), title: "In front"),
            window(2, Rect(x: 0, y: 0, width: 400, height: 300), title: "Behind"),
        ])
    }

    @Test("The window under a point is the one in front")
    func frontmostWins() throws {
        let found = try #require(overlapping().window(under: ScreenPoint(x: 200, y: 200)))
        #expect(found.title == "In front")
    }

    @Test("A point over only one window finds that one")
    func singleMatch() throws {
        let stack = overlapping()
        #expect(try #require(stack.window(under: ScreenPoint(x: 50, y: 50))).title == "Behind")
        #expect(try #require(stack.window(under: ScreenPoint(x: 450, y: 250))).title == "In front")
    }

    @Test("A point over nothing finds nothing")
    func noMatch() {
        #expect(overlapping().window(under: ScreenPoint(x: 900, y: 900)) == nil)
    }

    @Test("A higher layer beats the order of the list")
    func layerWins() throws {
        let stack = WindowStack(windows: [
            window(1, Rect(x: 0, y: 0, width: 400, height: 300), layer: 0, title: "Document"),
            window(2, Rect(x: 0, y: 0, width: 400, height: 300), layer: 25, title: "Menu"),
        ])
        #expect(try #require(stack.window(under: ScreenPoint(x: 50, y: 50))).title == "Menu")
    }

    @Test("A window that is not on screen is not under anything")
    func offScreenIgnored() {
        let stack = WindowStack(windows: [
            window(1, Rect(x: 0, y: 0, width: 400, height: 300), onScreen: false)
        ])
        #expect(stack.window(under: ScreenPoint(x: 50, y: 50)) == nil)
        #expect(stack.onScreen.isEmpty)
    }

    @Test("An empty stack answers nothing rather than failing")
    func emptyStack() {
        #expect(WindowStack(windows: []).window(under: ScreenPoint(x: 0, y: 0)) == nil)
    }

    @Test("A selection near a window's edges takes them")
    func snapsToEdges() {
        let stack = overlapping()
        let dragged = ScreenRect(Rect(x: 103, y: 98, width: 393, height: 304))
        let snapped = stack.snap(dragged, within: 6)
        #expect(snapped.minX == 100)
        #expect(snapped.minY == 100)
        #expect(snapped.maxX == 500)
        #expect(snapped.maxY == 400)
    }

    @Test("A selection far from any edge is left alone")
    func leavesDistantEdges() {
        let dragged = ScreenRect(Rect(x: 200, y: 200, width: 60, height: 40))
        #expect(overlapping().snap(dragged, within: 6) == dragged)
    }

    @Test("Each edge snaps on its own")
    func edgesAreIndependent() {
        let dragged = ScreenRect(Rect(x: 102, y: 200, width: 100, height: 40))
        let snapped = overlapping().snap(dragged, within: 6)
        #expect(snapped.minX == 100)
        #expect(snapped.minY == 200, "an edge with nothing near it should not move")
        #expect(snapped.raw.width == 102, "snapping an edge moves that edge, not the box")
    }

    @Test("Only visible windows are snapped to")
    func snapsOnlyToVisibleWindows() {
        let stack = WindowStack(windows: [
            window(1, Rect(x: 0, y: 0, width: 400, height: 300), onScreen: false)
        ])
        let dragged = ScreenRect(Rect(x: 3, y: 3, width: 100, height: 100))
        #expect(stack.snap(dragged, within: 6) == dragged)
    }

    @Test("Snapping is reproducible")
    func reproducible() {
        let stack = overlapping()
        let dragged = ScreenRect(Rect(x: 103, y: 98, width: 393, height: 304))
        #expect(isReproducible { stack.snap(dragged, within: 6) })
    }

    @Test("A window describes itself by title, or by application when it has none")
    func describing() {
        #expect(window(1, .zero, title: "Report.pdf", app: "Preview").describedName == "Report.pdf")
        #expect(window(1, .zero, title: nil, app: "Preview").describedName == "Preview")
        #expect(window(1, .zero, title: "", app: "Preview").describedName == "Preview")
    }

    @Test("Windows survive a round trip")
    func roundTrip() throws {
        #expect(try isJSONRoundTrippable(overlapping().windows))
    }
}
