import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoRender
import Testing

@Suite("Key caps on the picture")
struct KeyCapDrawingTests {
    private let canvas = SceneRect(x: 0, y: 0, width: 400, height: 300)

    private func scene(_ keys: [String]) -> Scene {
        Scene(
            canvas: canvas,
            background: nil,
            annotations: [],
            style: .standard,
            keys: keys
        )
    }

    private func list(_ keys: [String]) -> DrawList {
        DrawListBuilder(measurer: TabulatedTextMeasurer.uniform()).build(scene(keys))
    }

    private func texts(in list: DrawList) -> [String] {
        list.commands.compactMap { if case .text(let run) = $0 { run.text } else { nil } }
    }

    @Test("A picture with nothing typed on it draws no caps")
    func nothingTyped() {
        #expect(list([]).commands.isEmpty)
    }

    @Test("Every key that is up gets drawn")
    func everyKeyIsDrawn() {
        #expect(texts(in: list(["A", "B"])) == ["A", "B"])
    }

    @Test("A cap is drawn behind its letter, not over it")
    func plateBeforeText() throws {
        let commands = list(["A"]).commands
        let plate = try #require(commands.firstIndex { if case .fill = $0 { true } else { false } })
        let letter = try #require(
            commands.firstIndex { if case .text = $0 { true } else { false } })
        #expect(plate < letter)
    }

    private func plates(_ keys: [String]) -> [SceneRect] {
        list(keys).commands.compactMap { command in
            guard case .fill(let path, _) = command else { return nil }
            return path.bounds
        }
    }

    @Test("The caps sit along the bottom of the picture, inside it")
    func insideTheCanvas() {
        for box in plates(["A", "B", "C"]) {
            #expect(box.minX >= canvas.minX)
            #expect(box.maxX <= canvas.maxX)
            #expect(box.maxY <= canvas.maxY)
            #expect(box.minY > canvas.minY + canvas.height / Half.of)
        }
    }

    @Test("The caps are centred as a row, so the row does not drift as it grows")
    func centredAsARow() throws {
        func middle(_ keys: [String]) throws -> Double {
            let boxes = plates(keys)
            let left = try #require(boxes.map(\.minX).min())
            let right = try #require(boxes.map(\.maxX).max())
            return (left + right) / Half.of
        }
        let centre = canvas.minX + canvas.width / Half.of
        let alone = try middle(["A"])
        let together = try middle(["A", "B", "C"])
        #expect(abs(alone - centre) < Tolerance.middle)
        #expect(abs(together - centre) < Tolerance.middle)
    }

    @Test("A wide cap is drawn wider than a narrow one")
    func wideCapsAreWider() throws {
        let wide = try #require(plates(["⌃⌥⇧⌘4"]).first)
        let narrow = try #require(plates(["A"]).first)
        #expect(wide.width > narrow.width)
    }

    @Test("Caps never overlap each other")
    func noOverlap() {
        let boxes = plates(["A", "B", "C", "D"])
        for (place, box) in boxes.enumerated() where place + 1 < boxes.count {
            #expect(box.maxX <= boxes[place + 1].minX)
        }
    }

    private enum Half {
        static let of: Double = 2
    }

    private enum Tolerance {
        static let middle = 0.001
    }
}
