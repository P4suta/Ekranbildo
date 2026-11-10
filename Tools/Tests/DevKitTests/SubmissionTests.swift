@testable import DevKit
import Foundation
import Testing

@Suite("Submission")
struct SubmissionTests {
    private let team = "XMBQLW82L9"
    private let identifier = "app.ekranbildo.Ekranbildo"

    private func listing(_ names: [String]) -> String {
        names.enumerated()
            .map { "  \($0.offset + 1)) DEADBEEF \"\($0.element)\"" }
            .joined(separator: "\n")
    }

    private func certificates(codeSigning: [String], everything: [String]) -> Certificates {
        Certificates(from: [
            IdentityListing(policy: .codeSigning, raw: listing(codeSigning)),
            IdentityListing(policy: .everything, raw: listing(everything)),
        ])
    }

    @Test("The App Store wants the sandbox entitlements plus who the app belongs to")
    func entitlements() throws {
        let made = try Submission.entitlements(team: team, identifier: identifier)
        let read =
            try PropertyListSerialization.propertyList(from: made, format: nil)
            as? [String: Any]
        #expect(read?["com.apple.security.app-sandbox"] as? Bool == true)
        #expect(read?["com.apple.application-identifier"] as? String == "\(team).\(identifier)")
        #expect(read?["com.apple.developer.team-identifier"] as? String == team)
    }

    @Test("An installer certificate is looked for where it actually shows up")
    func installerIsNotACodeSigningIdentity() {
        let missing = Submission.missing(
            among: certificates(
                codeSigning: ["Apple Distribution: Someone (XMBQLW82L9)"],
                everything: [
                    "Apple Distribution: Someone (XMBQLW82L9)",
                    "3rd Party Mac Developer Installer: Someone (XMBQLW82L9)",
                ]),
            profile: URL(fileURLWithPath: "/tmp/Ekranbildo.provisionprofile")
        )
        #expect(missing.isEmpty)
    }

    @Test("An application certificate that only signs installers does not count")
    func installerCannotSignTheApplication() {
        let missing = Submission.missing(
            among: certificates(
                codeSigning: [],
                everything: ["3rd Party Mac Developer Installer: Someone (XMBQLW82L9)"]),
            profile: URL(fileURLWithPath: "/tmp/Ekranbildo.provisionprofile")
        )
        #expect(missing.map(\.requirement) == [.applicationCertificate])
    }

    @Test("Everything that is missing is named at once, not one at a time")
    func namesEverythingMissing() {
        let missing = Submission.missing(
            among: certificates(
                codeSigning: ["Apple Development: Someone (ABCDE12345)"],
                everything: ["Apple Development: Someone (ABCDE12345)"]),
            profile: nil
        )
        #expect(missing.count == Submission.Requirement.allCases.count)
        for requirement in Submission.Requirement.allCases {
            #expect(missing.contains { $0.requirement == requirement })
            #expect(!requirement.howToGetIt.isEmpty)
        }
    }

    @Test("Nothing is missing once both certificates and the profile are in place")
    func nothingMissing() {
        let both = [
            "3rd Party Mac Developer Application: Someone (XMBQLW82L9)",
            "3rd Party Mac Developer Installer: Someone (XMBQLW82L9)",
        ]
        let missing = Submission.missing(
            among: certificates(codeSigning: both, everything: both),
            profile: URL(fileURLWithPath: "/tmp/Ekranbildo.provisionprofile")
        )
        #expect(missing.isEmpty)
    }

    @Test("The installer is built for /Applications and signed by the installer certificate")
    func productbuild() {
        let arguments = Submission.productbuildArguments(
            bundle: URL(fileURLWithPath: "/tmp/Ekranbildo.app"),
            package: URL(fileURLWithPath: "/tmp/Ekranbildo.pkg"),
            identity: "3rd Party Mac Developer Installer: Someone (XMBQLW82L9)"
        )
        #expect(arguments.contains("--component"))
        #expect(arguments.contains("/Applications"))
        #expect(arguments.contains("3rd Party Mac Developer Installer: Someone (XMBQLW82L9)"))
        #expect(arguments.last == "/tmp/Ekranbildo.pkg")
    }

    @Test("A team the certificate does not name cannot be guessed")
    func teamFromIdentity() {
        #expect(
            Submission.team(of: "3rd Party Mac Developer Application: Someone (XMBQLW82L9)")
                == "XMBQLW82L9")
        #expect(Submission.team(of: "Ekranbildo Development") == nil)
    }
}
