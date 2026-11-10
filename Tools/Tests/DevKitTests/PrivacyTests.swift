@testable import DevKit
import Foundation
import Testing

@Suite("Privacy manifest")
struct PrivacyTests {
    private func manifest() throws -> [String: Any] {
        let layout = BundleLayout(
            name: "Ekranbildo", identifier: "app.ekranbildo.Ekranbildo",
            root: URL(fileURLWithPath: "/tmp"))
        let read = try PropertyListSerialization.propertyList(
            from: try layout.privacyContents(), format: nil)
        return try #require(read as? [String: Any])
    }

    @Test("Ekranbildo does not track anybody")
    func noTracking() throws {
        let read = try manifest()
        #expect(read["NSPrivacyTracking"] as? Bool == false)
        #expect((read["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test("Nothing about anybody is collected")
    func nothingCollected() throws {
        let collected = try manifest()["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        #expect(collected?.isEmpty == true)
    }

    @Test("No api that needs a reason is reached for")
    func noReasonsNeeded() throws {
        let reached = try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        #expect(reached?.isEmpty == true)
    }

    @Test("The manifest is where the App Store looks for it")
    func whereItBelongs() {
        let layout = BundleLayout(
            name: "Ekranbildo", identifier: "app.ekranbildo.Ekranbildo",
            root: URL(fileURLWithPath: "/tmp"))
        #expect(layout.privacy.lastPathComponent == "PrivacyInfo.xcprivacy")
        #expect(layout.privacy.deletingLastPathComponent().path == layout.resources.path)
    }

    @Test("Assembling a bundle puts the manifest in it")
    func assembledIn() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-privacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("ekranbildo-app")
        try Data().write(to: executable)

        let layout = BundleLayout(name: "Ekranbildo", identifier: "app.ekranbildo.Ekranbildo", root: root)
        try layout.assemble(from: executable)
        #expect(FileManager.default.fileExists(atPath: layout.privacy.path))
    }

    @Test("Every entitlement asked for is one the app actually needs")
    func everyEntitlementIsEarned() {
        let asked = BundleLayout.sandboxEntitlements.keys.sorted()
        #expect(asked == BundleLayout.whyEachEntitlement.map(\.name))
        for reason in BundleLayout.whyEachEntitlement {
            #expect(!reason.because.isEmpty)
        }
    }
}
