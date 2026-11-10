import Foundation


public struct ForbiddenName: Sendable, Hashable {
    public let symbol: String
    public let product: String
    public let reason: String

    public init(symbol: String, product: String = "ekranbildo-cli", reason: String) {
        self.product = product
        self.symbol = symbol
        self.reason = reason
    }
}

public enum ArtifactRules {
    public static func check(
        debug: String,
        release: String,
        names: [ForbiddenName]
    ) -> [Finding] {
        names.compactMap { name in
            guard debug.contains(name.symbol) else {
                return Finding(
                    path: name.symbol,
                    line: 0,
                    advice: "\(name.symbol) is missing from the debug binary too, so its "
                        + "absence from the release one proves nothing (\(name.reason))"
                )
            }
            guard release.contains(name.symbol) else { return nil }
            return Finding(
                path: name.symbol,
                line: 0,
                advice: "\(name.symbol) is in the release binary: \(name.reason)"
            )
        }
    }

    public static let forbidden = [
        ForbiddenName(
            symbol: "EkranbildoTestHooks",
            reason: "the control channel lets anything outside the process drive the editor"
        ),
        ForbiddenName(
            symbol: "HookSession", reason: "the channel's session holds the document"),
        ForbiddenName(symbol: "HookRouter", reason: "the channel's dispatch"),
        ForbiddenName(
            symbol: "captureTheScreenWithoutBeingAsked",
            product: "ekranbildo-app",
            reason: "the trigger that puts the capture overlay up without anybody asking"
        ),
    ]

    public static func products(of names: [ForbiddenName]) -> [String] {
        Array(Set(names.map(\.product))).sorted()
    }

    public static func names(in product: String, among names: [ForbiddenName])
        -> [ForbiddenName]
    {
        names.filter { $0.product == product }
    }

    public static func symbols(
        of configuration: String,
        product: String = "ekranbildo-cli",
        at root: URL
    ) throws -> String {
        let swift = try Toolchain.locate("swift").path()
        let built = try Command.run(
            swift, ["build", "-c", configuration, "--product", product], in: root)
        guard built.status == 0 else {
            throw Command.Failure(
                description: "the \(configuration) build did not succeed: \(built.output)")
        }

        let path = try Command.run(
            swift,
            ["build", "-c", configuration, "--product", product, "--show-bin-path"],
            in: root
        )
        let binary =
            path.output.trimmingCharacters(in: .whitespacesAndNewlines) + "/" + product

        let listed = try Command.run("/usr/bin/nm", [binary], in: root)
        guard listed.status == 0 else {
            throw Command.Failure(description: "could not read \(binary): \(listed.output)")
        }
        return try demangled(listed.output, at: root)
    }

    private static func demangled(_ symbols: String, at root: URL) throws -> String {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("ekranbildo-symbols-\(ProcessInfo.processInfo.processIdentifier)")
        try symbols.write(to: scratch, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let xcrun = try Toolchain.locate("xcrun").path()
        let outcome = try Command.run(
            "/bin/sh",
            ["-c", "\(xcrun) swift-demangle < \(scratch.path)"],
            in: root
        )
        return outcome.status == 0 ? outcome.output : symbols
    }
}


extension ArtifactRules {
    public static func complaint(about requirement: String, identifier: String) -> String? {
        guard requirement.contains("designated =>") else {
            return "the bundle has no designated requirement: it is not signed at all."
        }
        guard requirement.contains("identifier \"\(identifier)\"") else {
            return "the designated requirement does not name \(identifier), so a permission "
                + "granted to this bundle is granted to something else."
        }
        guard !requirement.contains("cdhash") else {
            return "the designated requirement is a hash of the binary, which means this was "
                + "signed ad-hoc. Every build is then a different application as far as the "
                + "screen recording permission is concerned, and it is granted again on each."
        }
        guard requirement.contains("certificate leaf") else {
            return "the designated requirement names no certificate, so there is nothing "
                + "stable for a privacy permission to be bound to."
        }
        return nil
    }
}
