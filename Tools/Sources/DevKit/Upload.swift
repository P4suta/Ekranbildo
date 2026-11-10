import Foundation

public struct AppStoreAccount: Codable, Hashable, Sendable {
    public let appleID: String
    public let keyID: String
    public let issuerID: String

    public init(appleID: String, keyID: String, issuerID: String) {
        self.appleID = appleID
        self.keyID = keyID
        self.issuerID = issuerID
    }

    public static func read(from file: URL) throws -> AppStoreAccount {
        try JSONDecoder().decode(AppStoreAccount.self, from: try Data(contentsOf: file))
    }

    public static func beside(_ root: URL) -> URL {
        root.appendingPathComponent(".signing/app-store-connect.json")
    }
}

public enum Upload {
    public enum Requirement: String, Sendable, CaseIterable {
        case account
        case privateKey

        public var howToGetIt: String {
            switch self {
            case .account:
                """
                Write .signing/app-store-connect.json with three things that are not
                secret: "appleID", the ten-digit number App Store Connect shows under
                App Information as the app's Apple ID; "keyID" and "issuerID", from
                Users and Access > Integrations > App Store Connect API, where a key
                with the Developer role is enough to upload a build.
                """
            case .privateKey:
                """
                Download the .p8 for that key - App Store Connect lets you do it once
                and never again - and put it at
                ~/.appstoreconnect/private_keys/AuthKey_<keyID>.p8, which is where
                altool looks for it. It is the only secret in any of this, and nothing
                will ever print it or pass it on a command line.
                """
            }
        }
    }

    public struct Absence: Sendable, Equatable {
        public let requirement: Requirement

        public init(requirement: Requirement) {
            self.requirement = requirement
        }
    }

    public static func keyName(for account: AppStoreAccount) -> String {
        "AuthKey_\(account.keyID).p8"
    }

    public static func key(for account: AppStoreAccount) -> URL? {
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".appstoreconnect/private_keys/\(keyName(for: account))")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    public static func missing(account: AppStoreAccount?, key: URL?) -> [Absence] {
        var absent: [Absence] = []
        if account == nil { absent.append(Absence(requirement: .account)) }
        if key == nil { absent.append(Absence(requirement: .privateKey)) }
        return absent
    }

    public static func arguments(package: URL, account: AppStoreAccount) -> [String] {
        [
            "altool",
            "--upload-package", package.path,
            "--type", Platform.macOS,
            "--apple-id", account.appleID,
            "--bundle-id", Packaging.identifier,
            "--bundle-version", BundleLayout.buildVersion,
            "--bundle-short-version-string", BundleLayout.marketingVersion,
            "--apiKey", account.keyID,
            "--apiIssuer", account.issuerID,
        ]
    }

    private enum Platform {
        static let macOS = "macos"
    }
}
