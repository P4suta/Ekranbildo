@testable import DevKit
import Foundation
import Testing

@Suite("Handing the build over")
struct UploadTests {
    private let account = AppStoreAccount(
        appleID: "6740000000", keyID: "ABC123XYZ9", issuerID: "1a2b3c4d-0000-0000-0000-000000000000")
    private let package = URL(fileURLWithPath: "/tmp/Ekranbildo.pkg")

    @Test("The secret is named, never spelled out")
    func noSecretOnTheCommandLine() {
        let arguments = Upload.arguments(package: package, account: account)
        #expect(arguments.contains("--apiKey"))
        #expect(arguments.contains(account.keyID))
        #expect(!arguments.contains { $0.contains("BEGIN PRIVATE KEY") })
        #expect(!arguments.contains("--password"))
        #expect(!arguments.contains("--username"))
    }

    @Test("It says which package, for which application, on which platform")
    func saysWhatItIsUploading() throws {
        let arguments = Upload.arguments(package: package, account: account)
        let file = try #require(arguments.firstIndex(of: "--upload-package"))
        #expect(arguments[file + 1] == package.path)
        let identifier = try #require(arguments.firstIndex(of: "--apple-id"))
        #expect(arguments[identifier + 1] == account.appleID)
        let platform = try #require(arguments.firstIndex(of: "--type"))
        #expect(arguments[platform + 1] == "macos")
    }

    @Test("The version it declares is the version the bundle carries")
    func versionsAgree() throws {
        let arguments = Upload.arguments(package: package, account: account)
        let marketing = try #require(arguments.firstIndex(of: "--bundle-short-version-string"))
        let build = try #require(arguments.firstIndex(of: "--bundle-version"))
        #expect(arguments[marketing + 1] == BundleLayout.marketingVersion)
        #expect(arguments[build + 1] == BundleLayout.buildVersion)
    }

    @Test("An account read back is the account that was written")
    func roundTrip() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("asc-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try JSONEncoder().encode(account).write(to: file)
        #expect(try AppStoreAccount.read(from: file) == account)
    }

    @Test("Everything missing is named at once, and the key is looked for where altool looks")
    func namesEverythingMissing() {
        let missing = Upload.missing(account: nil, key: nil)
        #expect(missing.count == Upload.Requirement.allCases.count)
        for requirement in Upload.Requirement.allCases {
            #expect(missing.contains { $0.requirement == requirement })
            #expect(!requirement.howToGetIt.isEmpty)
        }
        #expect(
            Upload.Requirement.privateKey.howToGetIt.contains(".appstoreconnect/private_keys"))
    }

    @Test("With the account written down and the key in place, nothing is missing")
    func nothingMissing() {
        let key = URL(fileURLWithPath: "/tmp/AuthKey_ABC123XYZ9.p8")
        #expect(Upload.missing(account: account, key: key).isEmpty)
    }

    @Test("The key is looked for under the name altool expects")
    func keyName() {
        #expect(Upload.keyName(for: account) == "AuthKey_ABC123XYZ9.p8")
    }
}
