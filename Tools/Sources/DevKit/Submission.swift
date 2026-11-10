import Foundation

public enum Submission {
    public enum Signature: Sendable, CaseIterable {
        case application
        case installer

        public var policy: IdentityListing.Policy {
            switch self {
            case .application: .codeSigning
            case .installer: .everything
            }
        }

        var prefixes: [String] {
            switch self {
            case .application:
                ["3rd Party Mac Developer Application:", "Apple Distribution:"]
            case .installer:
                ["3rd Party Mac Developer Installer:", "Apple Installer:"]
            }
        }
    }

    public enum Requirement: String, Sendable, CaseIterable {
        case applicationCertificate
        case installerCertificate
        case provisioningProfile

        public var howToGetIt: String {
            switch self {
            case .applicationCertificate:
                """
                Create a Mac App Distribution certificate on this Mac. In Xcode, \
                Settings › Accounts › Manage Certificates › + › Apple Distribution. \
                It must be made here so the private key is generated on this machine.
                """
            case .installerCertificate:
                """
                Create a Mac Installer Distribution certificate at \
                developer.apple.com/account/resources/certificates, download it and \
                open it. Xcode does not create this one for you.
                """
            case .provisioningProfile:
                """
                Register app.ekranbildo.Ekranbildo in App Store Connect, then create a Mac App \
                Store provisioning profile for it at \
                developer.apple.com/account/resources/profiles and save it as \
                .signing/Ekranbildo.provisionprofile.
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

    public static func missing(among certificates: Certificates, profile: URL?) -> [Absence] {
        var absent: [Absence] = []
        if certificates.identity(.application) == nil {
            absent.append(Absence(requirement: .applicationCertificate))
        }
        if certificates.identity(.installer) == nil {
            absent.append(Absence(requirement: .installerCertificate))
        }
        if profile == nil {
            absent.append(Absence(requirement: .provisioningProfile))
        }
        return absent
    }

    public static func team(of identity: String) -> String? {
        guard let opening = identity.lastIndex(of: "("),
            let closing = identity.lastIndex(of: ")"),
            opening < closing
        else { return nil }
        let inside = String(identity[identity.index(after: opening)..<closing])
        return inside.isEmpty ? nil : inside
    }

    public static func entitlements(team: String, identifier: String) throws -> Data {
        var listed = BundleLayout.sandboxEntitlements
        listed["com.apple.application-identifier"] = "\(team).\(identifier)"
        listed["com.apple.developer.team-identifier"] = team
        return try PropertyListSerialization.data(
            fromPropertyList: listed, format: .xml, options: 0)
    }

    public static func productbuildArguments(
        bundle: URL,
        package: URL,
        identity: String
    ) -> [String] {
        [
            "--component", bundle.path, Destination.applications,
            "--sign", identity,
            package.path,
        ]
    }

    public static let profileName = "Ekranbildo.provisionprofile"

    public static func profile(under root: URL) -> URL? {
        let file = root.appendingPathComponent(".signing/\(profileName)")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    public static func embeddedProfile(in bundle: URL) -> URL {
        bundle.appendingPathComponent("Contents/embedded.provisionprofile")
    }

    private enum Destination {
        static let applications = "/Applications"
    }
}
