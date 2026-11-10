@testable import DevKit
import Foundation
import Testing

@Suite("What a build signs with")
struct SigningChoiceTests {
    private let ourOwn = ProjectKeychain(
        name: "Ekranbildo Development",
        file: URL(fileURLWithPath: "/tmp/.signing/ekranbildo-dev.keychain-db")
    )

    private func certificates(_ names: [String], policy: IdentityListing.Policy = .codeSigning)
        -> Certificates
    {
        let text =
            names.enumerated()
            .map { "  \($0.offset + 1)) ABC123 \"\($0.element)\"" }
            .joined(separator: "\n") + "\n     \(names.count) valid identities found"
        return Certificates(from: [IdentityListing(policy: policy, raw: text)])
    }

    @Test("Asked for one by name, that is the one, and no keychain is unlocked for it")
    func askedByName() {
        let chosen = Signing.chosen(
            asked: "Somebody Else", among: certificates([]), ourOwn: ourOwn)
        #expect(chosen == .named("Somebody Else"))
        #expect(chosen.keychain == nil)
    }

    @Test("An Apple certificate is used in preference to the project's own")
    func prefersApple() {
        let chosen = Signing.chosen(
            asked: nil,
            among: certificates(["Apple Development: Someone (ABCDE12345)"]),
            ourOwn: ourOwn
        )
        #expect(chosen == .appleCertificate("Apple Development: Someone (ABCDE12345)"))
    }

    @Test("An Apple certificate needs no keychain of ours")
    func appleNeedsNoKeychain() {
        let chosen = Signing.chosen(
            asked: nil,
            among: certificates(["Apple Development: Someone (ABCDE12345)"]),
            ourOwn: ourOwn
        )
        #expect(chosen.keychain == nil)
    }

    @Test("With no Apple certificate, the project's own is used, out of its own keychain")
    func fallsBack() {
        let chosen = Signing.chosen(asked: nil, among: certificates([]), ourOwn: ourOwn)
        #expect(chosen == .ourOwn(ourOwn))
        #expect(chosen.keychain == ourOwn.file)
    }

    @Test("With nothing at all, a build is signed ad hoc and says so")
    func nothing() {
        let chosen = Signing.chosen(asked: nil, among: certificates([]), ourOwn: nil)
        #expect(chosen == .adHoc)
        #expect(chosen.identity == nil)
        #expect(chosen.keychain == nil)
    }

    @Test("A distribution certificate never signs a build meant to be run here")
    func neverDistribution() {
        let chosen = Signing.chosen(
            asked: nil,
            among: certificates([
                "Apple Distribution: Someone (TEAM123456)",
                "3rd Party Mac Developer Application: Someone (TEAM123456)",
            ]),
            ourOwn: ourOwn
        )
        #expect(chosen == .ourOwn(ourOwn))
    }

    @Test("With several Apple certificates, the same one is chosen every time")
    func stable() {
        let chosen = Signing.chosen(
            asked: nil,
            among: certificates([
                "Apple Development: Someone (ZZZZZ99999)",
                "Apple Development: Someone (AAAAA11111)",
            ]),
            ourOwn: nil
        )
        #expect(chosen == .appleCertificate("Apple Development: Someone (AAAAA11111)"))
    }

    @Test("Only the choice that has a keychain is the one that has to reach it")
    func onlyOursNeedsReaching() {
        let everyChoice: [Signing] = [
            .named("Somebody"), .appleCertificate("Apple Development: X (Y)"),
            .ourOwn(ourOwn), .adHoc,
        ]
        #expect(everyChoice.filter { $0.keychain != nil } == [.ourOwn(ourOwn)])
    }

    @Test("A listing read under one policy cannot answer a question about another")
    func policiesDoNotMix() {
        let onlyCodeSigning = certificates(
            ["3rd Party Mac Developer Installer: Someone (TEAM123456)"], policy: .codeSigning)
        #expect(onlyCodeSigning.identity(.installer) == nil)
    }

    @Test("Each question is asked of the listing that can answer it")
    func eachQuestionOfItsOwnListing() {
        let both = Certificates(from: [
            IdentityListing(
                policy: .codeSigning,
                raw: "  1) A \"Apple Distribution: Someone (TEAM123456)\""),
            IdentityListing(
                policy: .everything,
                raw: "  1) B \"3rd Party Mac Developer Installer: Someone (TEAM123456)\""),
        ])
        #expect(both.identity(.application) == "Apple Distribution: Someone (TEAM123456)")
        #expect(
            both.identity(.installer)
                == "3rd Party Mac Developer Installer: Someone (TEAM123456)")
    }

    @Test("Which policy a question needs is a property of the question")
    func questionsKnowTheirPolicy() {
        #expect(Submission.Signature.application.policy == .codeSigning)
        #expect(Submission.Signature.installer.policy == .everything)
    }

    @Test("A policy says for itself how it is asked for")
    func policiesAskForThemselves() {
        #expect(IdentityListing.Policy.codeSigning.arguments.contains("codesigning"))
        #expect(!IdentityListing.Policy.everything.arguments.contains("-p"))
    }
}
