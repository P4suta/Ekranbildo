@testable import DevKit
import Foundation
import Testing


@Suite("The application bundle")
struct BundleTests {

    private let layout = BundleLayout(name: "Ekranbildo", identifier: "app.ekranbildo.Ekranbildo")

    @Test("The executable goes where the launcher looks for it")
    func executablePath() {
        #expect(layout.executable.path.hasSuffix("Ekranbildo.app/Contents/MacOS/Ekranbildo"))
    }

    @Test("The plist goes beside it")
    func plistPath() {
        #expect(layout.plist.path.hasSuffix("Ekranbildo.app/Contents/Info.plist"))
    }


    private func plist() throws -> [String: Any] {
        let data = try layout.plistContents()
        let read = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(read as? [String: Any])
    }

    @Test("It says what it is called and what it is")
    func identity() throws {
        let read = try plist()
        #expect(read["CFBundleIdentifier"] as? String == "app.ekranbildo.Ekranbildo")
        #expect(read["CFBundleExecutable"] as? String == "Ekranbildo")
        #expect(read["CFBundlePackageType"] as? String == "APPL")
    }

    @Test("It is an accessory, not a Dock application")
    func isAnAccessory() throws {
        #expect(try plist()["LSUIElement"] as? Bool == true)
    }

    @Test("It says why it wants the microphone, in a sentence somebody reads")
    func usageDescriptions() throws {
        let reason = try #require(plist()["NSMicrophoneUsageDescription"] as? String)
        #expect(reason.count > 40)
        #expect(reason.contains("record"))
    }

    @Test("It asks for a version of macOS that has what it uses")
    func minimumSystem() throws {
        let minimum = try #require(plist()["LSMinimumSystemVersion"] as? String)
        #expect(minimum.hasPrefix("15"))
    }


    private func entitlements() throws -> [String: Any] {
        let data = try layout.entitlementsContents()
        let read = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(read as? [String: Any])
    }

    @Test("It is sandboxed, which the store requires and the design assumes")
    func isSandboxed() throws {
        #expect(try entitlements()["com.apple.security.app-sandbox"] as? Bool == true)
    }

    @Test(
        "It asks for what it needs",
        arguments: [
            "com.apple.security.files.user-selected.read-write",
            "com.apple.security.device.audio-input",
        ])
    func asksForWhatItNeeds(entitlement: String) throws {
        #expect(try entitlements()[entitlement] as? Bool == true)
    }

    @Test("It does not ask for an entitlement that does not exist")
    func noInventedEntitlements() throws {
        let asked = try entitlements().keys.sorted()
        #expect(!asked.contains { $0.contains("screen-capture") })
        #expect(!asked.contains { $0.contains("temporary-exception") })
    }

    @Test("It asks for nothing it cannot account for")
    func asksForNothingElse() throws {
        #expect(try entitlements().count == BundleLayout.whyEachEntitlement.count)
    }

    @Test("It does not ask to reach the network, because nothing in it does")
    func asksForNoNetwork() throws {
        #expect(!(try entitlements().keys.contains { $0.contains("network") }))
    }
}

@Suite("What a bundle has to say to be submitted")
struct SubmissionReadinessTests {

    private let layout = BundleLayout(
        name: "Ekranbildo",
        identifier: "app.ekranbildo.Ekranbildo",
        root: URL(fileURLWithPath: "/tmp")
    )

    private func plist() throws -> [String: Any] {
        let data = try layout.plistContents()
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    @Test("It says what it is called and who owns it")
    func namedAndOwned() throws {
        let contents = try plist()
        #expect(contents["CFBundleDisplayName"] as? String == "Ekranbildo")
        #expect((contents["NSHumanReadableCopyright"] as? String)?.isEmpty == false)
    }

    @Test("It answers the encryption question in advance")
    func encryption() throws {
        #expect(try plist()["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    }

    @Test("It names an icon")
    func icon() throws {
        #expect(try plist()["CFBundleIconFile"] as? String == "Ekranbildo")
    }

    @Test("It says which category it belongs in")
    func category() throws {
        #expect(
            try plist()["LSApplicationCategoryType"] as? String
                == "public.app-category.productivity")
    }

    @Test("It says why it wants to see the screen")
    func screenRecording() throws {
        let said = try #require(plist()["NSScreenCaptureUsageDescription"] as? String)
        #expect(said.count > 40)
    }

    @Test("Everything it says about itself is still there")
    func theRest() throws {
        let contents = try plist()
        #expect(contents["CFBundleIdentifier"] as? String == "app.ekranbildo.Ekranbildo")
        #expect(contents["LSUIElement"] as? Bool == true)
        #expect(contents["NSMicrophoneUsageDescription"] != nil)
    }
}

@Suite("The icon inside the bundle")
struct BundleIconTests {

    private func layout(at root: URL) -> BundleLayout {
        BundleLayout(name: "Ekranbildo", identifier: "app.ekranbildo.Ekranbildo", root: root)
    }

    private func temporary() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-icon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("It goes beside the other resources, under the name the plist gives")
    func whereItGoes() throws {
        let root = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = layout(at: root)
        #expect(layout.icon.lastPathComponent == "Ekranbildo.icns")
        #expect(layout.icon.deletingLastPathComponent().path == layout.resources.path)
    }

    @Test("A bundle without one says so")
    func missing() throws {
        let root = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = layout(at: root)
        let executable = root.appendingPathComponent("ekranbildo-app")
        try Data().write(to: executable)
        try layout.assemble(from: executable)
        #expect(!layout.hasAnIcon)
    }

    @Test("A bundle with one says so too")
    func present() throws {
        let root = try temporary()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = layout(at: root)
        let executable = root.appendingPathComponent("ekranbildo-app")
        try Data().write(to: executable)
        try layout.assemble(from: executable)
        try Data([1, 2, 3]).write(to: layout.icon)
        #expect(layout.hasAnIcon)
    }
}
