import Foundation


public struct Snippet: Sendable, Hashable {
    public enum Expectation: Sendable, Hashable {
        case compiles
        case isRejected
    }

    public enum Verdict: Sendable, Hashable {
        case asExpected
        case unexpected
    }

    public let name: String
    public let expectation: Expectation
    public let source: String

    public init(name: String, expectation: Expectation, source: String) {
        self.name = name
        self.expectation = expectation
        self.source = source
    }

    public func verdict(compiled: Bool) -> Verdict {
        switch expectation {
        case .compiles: compiled ? .asExpected : .unexpected
        case .isRejected: compiled ? .unexpected : .asExpected
        }
    }

    public func report(compiled: Bool) -> String {
        switch (expectation, compiled) {
        case (.compiles, true): "  accepted                    \(name)"
        case (.compiles, false): "  REJECTED (should compile)   \(name)"
        case (.isRejected, false): "  rejected                    \(name)"
        case (.isRejected, true): "  COMPILED (should not have)  \(name)"
        }
    }
}

public enum Snippets {
    public static let all: [Snippet] = [
        Snippet(
            name: "the baseline snippet compiles",
            expectation: .compiles,
            source: """
                import EkranbildoContracts
                func use() {
                    let point = ScenePoint(x: 1, y: 2)
                    _ = point
                }
                """
        ),
        Snippet(
            name: "a ScreenPoint cannot be passed where a ScenePoint is expected",
            expectation: .isRejected,
            source: """
                import EkranbildoContracts
                func takesScene(_ point: ScenePoint) {}
                func use() { takesScene(ScreenPoint(x: 1, y: 2)) }
                """
        ),
        Snippet(
            name: "an ImagePixel cannot be passed where a DisplayPixel is expected",
            expectation: .isRejected,
            source: """
                import EkranbildoContracts
                func takesDisplay(_ point: DisplayPixel) {}
                func use() { takesDisplay(ImagePixel(x: 1, y: 2)) }
                """
        ),
        Snippet(
            name: "rects in different spaces cannot be compared",
            expectation: .isRejected,
            source: """
                import EkranbildoContracts
                func use() -> Bool {
                    SceneRect(x: 0, y: 0, width: 1, height: 1)
                        == ScreenRect(x: 0, y: 0, width: 1, height: 1)
                }
                """
        ),
        Snippet(
            name: "converting scene to image pixels requires a capture geometry",
            expectation: .isRejected,
            source: """
                import EkranbildoContracts
                func use(_ point: ScenePoint) -> ImagePixel {
                    ImagePixel(point)
                }
                """
        ),
    ]

    public static func compiles(_ snippet: Snippet, against modules: URL, in root: URL) throws
        -> Bool
    {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("ekranbildo-snippet-\(UUID().uuidString).swift")
        try snippet.source.write(to: scratch, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let xcrun = try Toolchain.locate("xcrun").path()
        let outcome = try Command.run(
            xcrun,
            [
                "swiftc", "-swift-version", "6", "-typecheck",
                "-I", modules.appendingPathComponent("Modules").path,
                "-I", modules.path,
                "-L", modules.path,
                scratch.path,
            ],
            in: root
        )
        return outcome.status == 0
    }
}
