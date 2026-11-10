import Foundation

public struct Packaging: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public struct Refusal: Error {
        public let detail: String

        public init(detail: String) {
            self.detail = detail
        }
    }

    public static let name = "Ekranbildo"
    public static let identifier = "app.ekranbildo.Ekranbildo"

    public func assemble(_ configuration: Configuration) throws -> BundleLayout {
        let swift = try Toolchain.locate("swift").path()
        let built = try Command.run(
            swift, ["build", "-c", configuration.name, "--product", "ekranbildo-app"], in: root)
        guard built.status == 0 else {
            throw Refusal(detail: "the application did not build:\n\(built.output)")
        }

        let shown = try Command.run(
            swift,
            ["build", "-c", configuration.name, "--product", "ekranbildo-app", "--show-bin-path"],
            in: root
        )
        let products = URL(
            fileURLWithPath: shown.output.trimmingCharacters(in: .whitespacesAndNewlines))

        let layout = BundleLayout(name: Self.name, identifier: Self.identifier, root: products)
        try layout.assemble(from: products.appendingPathComponent("ekranbildo-app"))
        try draw(into: layout, configuration: configuration, swift: swift)
        return layout
    }

    private func draw(
        into layout: BundleLayout,
        configuration: Configuration,
        swift: String
    ) throws {
        let staging = root.appendingPathComponent(".build/iconset")
        let drawn = try Command.run(
            swift,
            ["run", "-c", configuration.name, "ekranbildo-cli", "icon", "--out", staging.path],
            in: root
        )
        guard drawn.status == 0 else {
            throw Refusal(detail: "the icon did not draw:\n\(drawn.output)")
        }

        let iconset = root.appendingPathComponent(".build/\(Self.name).iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.moveItem(at: staging, to: iconset)
        try? FileManager.default.removeItem(
            at: iconset.appendingPathComponent(Icon.tooLarge))

        let packed = try Command.run(
            "/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", layout.icon.path], in: root)
        guard packed.status == 0 else {
            throw Refusal(detail: "the icon did not pack:\n\(packed.output)")
        }
        guard layout.hasAnIcon else { throw Refusal(detail: "the bundle has no icon") }
    }

    private enum Icon {
        static let tooLarge = "icon_1024x1024@2x.png"
    }
}

public enum Configuration: String, Sendable, CaseIterable {
    case debug
    case release

    public var name: String { rawValue }
}
