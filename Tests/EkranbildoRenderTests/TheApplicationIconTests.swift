import EkranbildoContracts
import EkranbildoGeometry
@testable import EkranbildoRender
import Testing

@Suite("The application's own icon")
struct TheApplicationIconTests {

    private func drawing(_ side: Double) -> DrawList {
        ApplicationIcon.drawList(side: side)
    }

    @Test("It is square, at whatever size it is asked for", arguments: [16.0, 128.0, 1024.0])
    func square(_ side: Double) {
        let list = drawing(side)
        #expect(list.canvas.width == side)
        #expect(list.canvas.height == side)
    }

    @Test("Everything it draws is inside it", arguments: [16.0, 512.0, 1024.0])
    func insideItself(_ side: Double) {
        let box = Rect(x: 0, y: 0, width: side, height: side)
        for command in drawing(side).commands {
            guard let bounds = Self.bounds(of: command) else { continue }
            #expect(box.contains(bounds.raw), "\(bounds) is outside \(box)")
        }
    }

    @Test("It is the same drawing at every size")
    func sameAtEverySize() {
        #expect(drawing(16).commands.count == drawing(1024).commands.count)
    }

    @Test("It scales rather than being redrawn")
    func scales() throws {
        let small = try #require(Self.bounds(of: drawing(100).commands[0]))
        let large = try #require(Self.bounds(of: drawing(200).commands[0]))
        #expect(large.width == small.width * 2)
    }

    @Test("It draws something")
    func drawsSomething() {
        #expect(drawing(1024).commands.count > 1)
    }

    @Test("The same size always draws the same list")
    func reproducible() {
        let once = drawing(512)
        let again = drawing(512)
        #expect(once == again)
    }

    @Test("Every size the system asks for is one it can be drawn at")
    func everySystemSize() {
        for side in ApplicationIcon.sizes {
            #expect(!drawing(Double(side)).commands.isEmpty)
        }
        #expect(ApplicationIcon.sizes.contains(1024))
        #expect(ApplicationIcon.sizes.contains(16))
    }

    private static func bounds(of command: DrawCommand) -> SceneRect? {
        switch command {
        case .fill(let path, _): path.bounds
        case .stroke(let path, _): path.bounds
        case .image(_, let rect, _, _): rect
        default: nil
        }
    }
}
