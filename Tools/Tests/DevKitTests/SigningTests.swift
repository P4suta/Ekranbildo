@testable import DevKit
import Foundation
import Testing


@Suite("Signing the bundle")
struct SigningTests {

    private let entitlements = URL(fileURLWithPath: "/tmp/entitlements.plist")
    private let bundle = URL(fileURLWithPath: "/tmp/Ekranbildo.app")
    private let keychain = URL(fileURLWithPath: "/tmp/ekranbildo-dev.keychain-db")

    private func arguments(identity: String?, keychain: URL?) -> [String] {
        BundleLayout.arguments(
            identity: identity,
            keychain: keychain,
            entitlements: entitlements,
            bundle: bundle
        )
    }

    @Test("No identity is ad-hoc")
    func adHoc() {
        let made = arguments(identity: nil, keychain: nil)
        #expect(made.contains(BundleLayout.adHoc))
        #expect(!made.contains("--keychain"))
    }

    @Test("An identity is passed on as asked")
    func named() {
        #expect(arguments(identity: "Ekranbildo Development", keychain: nil)
            .contains("Ekranbildo Development"))
    }

    @Test("A keychain is where the identity is looked for")
    func keychainGiven() throws {
        let made = arguments(identity: "Ekranbildo Development", keychain: keychain)
        let flag = try #require(made.firstIndex(of: "--keychain"))
        #expect(made[flag + 1] == keychain.path)
    }

    @Test("The entitlements are always part of the signature")
    func entitlementsAlways() throws {
        for keychain in [nil, keychain] {
            for identity in [nil, "Ekranbildo Development"] {
                let made = arguments(identity: identity, keychain: keychain)
                let flag = try #require(made.firstIndex(of: "--entitlements"))
                #expect(made[flag + 1] == entitlements.path)
                #expect(made.contains("--options"))
            }
        }
    }

    @Test("What is signed is the bundle, and it comes last")
    func bundleLast() {
        #expect(arguments(identity: nil, keychain: nil).last == bundle.path)
    }

    @Test("A project with no certificate has no development identity")
    func noCertificate() throws {
        let empty = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-signing-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        #expect(ProjectKeychain.under(empty) == nil)
    }

    @Test("A project with a certificate signs with it")
    func withCertificate() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ekranbildo-signing-yes-\(ProcessInfo.processInfo.processIdentifier)")
        let signing = root.appendingPathComponent(".signing")
        try FileManager.default.createDirectory(at: signing, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: signing.appendingPathComponent("ekranbildo-dev.keychain-db"))

        let found = try #require(ProjectKeychain.under(root))
        #expect(found.name == BundleLayout.developmentIdentityName)
        #expect(found.file.lastPathComponent == "ekranbildo-dev.keychain-db")
    }
}


@Suite("Whether codesign can see the certificate")
struct KeychainReachTests {

    private let keychain = URL(fileURLWithPath: "/Users/someone/project/.signing/dev.keychain-db")
    private let login = "    \"/Users/someone/Library/Keychains/login.keychain-db\""

    @Test("A keychain in the search list is reachable")
    func inTheList() {
        #expect(
            BundleLayout.reachable(
                keychain: keychain,
                searchList: [login, "    \"\(keychain.path)\""]
            ))
    }

    @Test("A keychain not in the search list is not reachable")
    func notInTheList() {
        #expect(!BundleLayout.reachable(keychain: keychain, searchList: [login]))
    }

    @Test("An empty search list reaches nothing")
    func emptyList() {
        #expect(!BundleLayout.reachable(keychain: keychain, searchList: []))
    }

    @Test("What it says is the line that fixes it")
    func theMessageIsTheCommand() {
        let said = BundleLayout.howToReach(keychain, searchList: [login])
        #expect(said.contains("security list-keychains -d user -s"))
        #expect(said.contains("/Users/someone/Library/Keychains/login.keychain-db"))
        #expect(said.contains(keychain.path))
    }

    @Test("What it says keeps the keychains that are already there")
    func keepsWhatIsThere() {
        let other = "    \"/Users/someone/Library/Keychains/other.keychain-db\""
        let said = BundleLayout.howToReach(keychain, searchList: [login, other])
        #expect(said.contains("other.keychain-db"))
        #expect(said.contains("login.keychain-db"))
    }
}


@Suite("What the designated requirement has to say")
struct DesignatedRequirementTests {

    private let identifier = "app.ekranbildo.Ekranbildo"

    private func complaint(_ requirement: String) -> String? {
        ArtifactRules.complaint(about: requirement, identifier: identifier)
    }

    @Test("A requirement naming the identifier and a certificate is what is wanted")
    func good() {
        #expect(
            complaint(
                "designated => identifier \"app.ekranbildo.Ekranbildo\" and certificate leaf = H\"00ff\""
            ) == nil)
    }

    @Test("A requirement that is a hash of the binary is the ad-hoc case")
    func adHoc() throws {
        let said = try #require(
            complaint("designated => identifier \"app.ekranbildo.Ekranbildo\" and cdhash H\"00ff\""))
        #expect(said.contains("ad-hoc"))
    }

    @Test("A bundle with no requirement at all is not signed")
    func unsigned() throws {
        #expect(try #require(complaint("")).contains("not signed"))
    }

    @Test("A requirement for some other bundle is not this one's")
    func wrongIdentifier() throws {
        let said = try #require(
            complaint("designated => identifier \"app.other.Thing\" and certificate leaf = H\"00\""))
        #expect(said.contains("app.ekranbildo.Ekranbildo"))
    }

    @Test("A requirement with neither a hash nor a certificate binds to nothing")
    func nothingStable() throws {
        #expect(
            try #require(complaint("designated => identifier \"app.ekranbildo.Ekranbildo\""))
                .contains("nothing"))
    }
}
