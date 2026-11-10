import Foundation


public struct BundleLayout: Sendable {
    public let name: String
    public let identifier: String
    public let root: URL

    public init(
        name: String,
        identifier: String,
        root: URL = URL(fileURLWithPath: ".")
    ) {
        self.name = name
        self.identifier = identifier
        self.root = root
    }

    public var bundle: URL { root.appendingPathComponent("\(name).app") }
    public var contents: URL { bundle.appendingPathComponent("Contents") }
    public var executable: URL {
        contents.appendingPathComponent("MacOS").appendingPathComponent(name)
    }
    public var resources: URL { contents.appendingPathComponent("Resources") }
    public var plist: URL { contents.appendingPathComponent("Info.plist") }
    public var privacy: URL { resources.appendingPathComponent("PrivacyInfo.xcprivacy") }


    public func plistContents() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: information, format: .xml, options: 0)
    }

    private var information: [String: Any] {
        [
            "CFBundleIdentifier": identifier,
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundleIconFile": name,
            "LSApplicationCategoryType": "public.app-category.productivity",
            "ITSAppUsesNonExemptEncryption": false,
            "NSHumanReadableCopyright": Usage.copyright,
            "NSScreenCaptureUsageDescription": Usage.screen,
            "CFBundleExecutable": name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": Version.marketing,
            "CFBundleVersion": Version.build,
            "LSUIElement": true,
            "LSMinimumSystemVersion": Version.minimumSystem,
            "NSMicrophoneUsageDescription": Usage.microphone,
            "NSCameraUsageDescription": Usage.camera,
        ]
    }


    public func privacyContents() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: privacyManifest, format: .xml, options: 0)
    }

    private var privacyManifest: [String: Any] {
        [
            "NSPrivacyTracking": false,
            "NSPrivacyTrackingDomains": [String](),
            "NSPrivacyCollectedDataTypes": [[String: Any]](),
            "NSPrivacyAccessedAPITypes": [[String: Any]](),
        ]
    }

    public struct EntitlementReason: Sendable, Equatable {
        public let name: String
        public let because: String

        public init(name: String, because: String) {
            self.name = name
            self.because = because
        }
    }

    public static let whyEachEntitlement = [
        EntitlementReason(
            name: "com.apple.security.app-sandbox",
            because: "the App Store will not take an application without it"
        ),
        EntitlementReason(
            name: "com.apple.security.device.audio-input",
            because: "a recording can carry what was said over it"
        ),
        EntitlementReason(
            name: "com.apple.security.files.user-selected.read-write",
            because: "a picture is saved where the person saving it chose to put it"
        ),
    ]

    public func entitlementsContents() throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: entitlements, format: .xml, options: 0)
    }

    private var entitlements: [String: Any] { Self.sandboxEntitlements }

    static var sandboxEntitlements: [String: Any] {
        [
            "com.apple.security.app-sandbox": true,
            "com.apple.security.files.user-selected.read-write": true,
            "com.apple.security.device.audio-input": true,
        ]
    }

    private enum Version {
        static let marketing = "0.1"
        static let build = "1"
        static let minimumSystem = "15.0"
    }

    private enum Usage {
        static let copyright = "Copyright © 2026 Ekranbildo. All rights reserved."
        static let screen =
            "Ekranbildo takes the picture you are about to annotate. It reads the screen only "
            + "while you are capturing, and nothing it captures leaves your Mac unless you "
            + "send it somewhere yourself."

        static let microphone =
            "Ekranbildo records your microphone when you ask it to narrate a screen "
            + "recording. Nothing is recorded until you start one, and nothing "
            + "leaves your Mac."
        static let camera =
            "Ekranbildo does not use the camera. This is here because a recording "
            + "can include a window belonging to an application that does."
    }
}

extension BundleLayout {
    public func assemble(from executable: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: bundle.path) {
            try manager.removeItem(at: bundle)
        }
        try manager.createDirectory(
            at: self.executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.createDirectory(at: resources, withIntermediateDirectories: true)
        try manager.copyItem(at: executable, to: self.executable)
        try plistContents().write(to: plist)
        try privacyContents().write(to: privacy)
    }

    public func sign(_ signing: Signing, at root: URL) throws -> Outcome {
        let entitlements = FileManager.default.temporaryDirectory
            .appendingPathComponent("ekranbildo-entitlements.plist")
        try entitlementsContents().write(to: entitlements)
        defer { try? FileManager.default.removeItem(at: entitlements) }

        return try Command.run(
            "/usr/bin/codesign",
            Self.arguments(
                identity: signing.identity,
                keychain: signing.keychain,
                entitlements: entitlements,
                bundle: bundle
            ),
            in: root
        )
    }

    static func arguments(
        identity: String?,
        keychain: URL?,
        entitlements: URL,
        bundle: URL
    ) -> [String] {
        var arguments = ["--force", "--sign", identity ?? adHoc]
        if let keychain {
            arguments += ["--keychain", keychain.path]
        }
        arguments += [
            "--entitlements", entitlements.path,
            "--options", "runtime",
            bundle.path,
        ]
        return arguments
    }

    static let adHoc = "-"

    public static func reachable(keychain: URL, searchList: [String]) -> Bool {
        searchList.contains { $0.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            == keychain.path
        }
    }

    public static func howToReach(_ keychain: URL, searchList: [String]) -> String {
        let quoted = searchList.map {
            $0.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return """
            the signing certificate is there but codesign cannot see it: \
            \(keychain.lastPathComponent) is not in the keychain search list.

                security list-keychains -d user -s \
            \((quoted + [keychain.path]).joined(separator: " "))

            Without it every build is signed ad-hoc, and an ad-hoc signature \
            changes with the binary - so the screen recording permission is \
            granted again on every build.
            """
    }

    public static var marketingVersion: String { Version.marketing }
    public static var buildVersion: String { Version.build }

    public var icon: URL { resources.appendingPathComponent("\(name).icns") }

    public var hasAnIcon: Bool { FileManager.default.fileExists(atPath: icon.path) }

    public static let developmentIdentityName = "Ekranbildo Development"

    static let appleDevelopmentPrefix = "Apple Development:"

    static func quoted(_ line: some StringProtocol) -> String? {
        guard let opening = line.firstIndex(of: "\""),
            let closing = line.lastIndex(of: "\""),
            opening < closing
        else { return nil }
        return String(line[line.index(after: opening)..<closing])
    }

    public static func unlock(_ keychain: URL, in root: URL) throws -> Outcome {
        let password = keychain.deletingLastPathComponent().appendingPathComponent("password")
        let secret = try String(contentsOf: password, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try Command.run(
            "/usr/bin/security",
            ["unlock-keychain", "-p", secret, keychain.path],
            in: root
        )
    }
}
