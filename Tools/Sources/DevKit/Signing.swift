import Foundation

public struct IdentityListing: Sendable, Equatable {
    public enum Policy: Sendable, Equatable, CaseIterable {
        case codeSigning
        case everything

        public var arguments: [String] {
            switch self {
            case .codeSigning: ["find-identity", "-v", "-p", "codesigning"]
            case .everything: ["find-identity", "-v"]
            }
        }
    }

    public let policy: Policy
    public let raw: String

    public init(policy: Policy, raw: String) {
        self.policy = policy
        self.raw = raw
    }

    public var names: [String] {
        raw.split(separator: "\n").compactMap(BundleLayout.quoted)
    }

    public func first(startingWith prefixes: [String]) -> String? {
        for prefix in prefixes {
            let matching = names.filter { $0.hasPrefix(prefix) }.sorted()
            if let first = matching.first { return first }
        }
        return nil
    }
}

public struct Certificates: Sendable {
    private let listings: [IdentityListing]

    public init(from listings: [IdentityListing]) {
        self.listings = listings
    }

    public static func onThisMachine(in root: URL) throws -> Certificates {
        Certificates(
            from: try IdentityListing.Policy.allCases.map { policy in
                IdentityListing(
                    policy: policy,
                    raw: try Command.run("/usr/bin/security", policy.arguments, in: root).output
                )
            })
    }

    func listing(_ policy: IdentityListing.Policy) -> IdentityListing? {
        listings.first { $0.policy == policy }
    }

    public func identity(_ signature: Submission.Signature) -> String? {
        listing(signature.policy)?.first(startingWith: signature.prefixes)
    }

    public func development() -> String? {
        listing(.codeSigning)?.first(startingWith: [BundleLayout.appleDevelopmentPrefix])
    }
}

public struct ProjectKeychain: Sendable, Equatable {
    public let name: String
    public let file: URL

    public init(name: String, file: URL) {
        self.name = name
        self.file = file
    }

    public static func under(_ root: URL) -> ProjectKeychain? {
        let file = root.appendingPathComponent(".signing/ekranbildo-dev.keychain-db")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return ProjectKeychain(name: BundleLayout.developmentIdentityName, file: file)
    }
}

public enum Signing: Sendable, Equatable {
    case named(String)
    case appleCertificate(String)
    case ourOwn(ProjectKeychain)
    case adHoc

    public static func chosen(
        asked: String?,
        among certificates: Certificates,
        ourOwn: ProjectKeychain?
    ) -> Signing {
        if let asked { return .named(asked) }
        if let apple = certificates.development() { return .appleCertificate(apple) }
        if let ourOwn { return .ourOwn(ourOwn) }
        return .adHoc
    }

    public var identity: String? {
        switch self {
        case .named(let name): name
        case .appleCertificate(let name): name
        case .ourOwn(let keychain): keychain.name
        case .adHoc: nil
        }
    }

    public var keychain: URL? {
        switch self {
        case .named, .appleCertificate, .adHoc: nil
        case .ourOwn(let keychain): keychain.file
        }
    }

    public var worthSaying: String? {
        switch self {
        case .appleCertificate(let name): "signed with \(name)"
        case .named, .ourOwn, .adHoc: nil
        }
    }
}
