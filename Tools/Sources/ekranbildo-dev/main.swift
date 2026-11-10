import DevKit
import Foundation


setvbuf(stdout, nil, _IOLBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ekranbildo-dev: \(message)\n".utf8))
    exit(1)
}

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

guard let verb = arguments.first else {
    print(
        """
        ekranbildo-dev check [--fast]   run every check the gate runs
        ekranbildo-dev stage <name>     run one of them
        ekranbildo-dev list             say what it would run, without running it
        ekranbildo-dev fix              apply every correction that needs no decision
        ekranbildo-dev app [identity]   build Ekranbildo.app and sign it
        ekranbildo-dev app-debug        the same, with the diagnostics compiled in
        ekranbildo-dev submit           build the signed .pkg for the App Store
        ekranbildo-dev upload           build it and hand it to App Store Connect
        ekranbildo-dev determinism      the rules that keep output the same everywhere
        """)
    exit(1)
}

let checks = Checks(root: root, brief: arguments.contains("--fast"))

switch verb {
case "list":
    for stage in try checks.stages() {
        print(stage.name)
    }

case "determinism":
    let found = try DeterminismRules.scan(
        Checks.coreModules.map { root.appendingPathComponent("Sources/\($0)") })
    for finding in found {
        print("  \(finding.path):\(finding.line)")
        print("      \(finding.advice)")
    }
    print(found.isEmpty ? "    ok" : "FAILED: \(found.count) determinism violation(s)")
    exit(found.isEmpty ? 0 : 1)

case "fix":
    let context = Context(root: root)
    for stage in try checks.fixes() {
        let result = StageResult(attempting: stage, in: context)
        guard result.verdict == .passed else {
            fail("\(stage.name): \(result.outcome.output)")
        }
    }
    print("formatted, and the lint fixes applied")

case "app", "app-debug":
    let configuration: Configuration = verb == "app-debug" ? .debug : .release
    let layout: BundleLayout
    do {
        layout = try Packaging(root: root).assemble(configuration)
    } catch let refusal as Packaging.Refusal {
        fail(refusal.detail)
    }

    let signing = Signing.chosen(
        asked: arguments.dropFirst().first,
        among: try Certificates.onThisMachine(in: root),
        ourOwn: ProjectKeychain.under(root)
    )

    switch signing {
    case .ourOwn(let ours):
        let listed = try Command.run(
            "/usr/bin/security", ["list-keychains", "-d", "user"], in: root)
        let searchList = listed.output.split(separator: "\n").map(String.init)
        guard BundleLayout.reachable(keychain: ours.file, searchList: searchList) else {
            fail(BundleLayout.howToReach(ours.file, searchList: searchList))
        }
        _ = try? BundleLayout.unlock(ours.file, in: root)
    case .named, .appleCertificate, .adHoc:
        break
    }

    if let said = signing.worthSaying { print("    \(said)") }

    let signed = try layout.sign(signing, at: root)
    guard signed.status == 0 else { fail("could not sign:\n\(signed.output)") }

    let requirement = try Command.run(
        "/usr/bin/codesign", ["-d", "-r-", layout.bundle.path], in: root)
    if let complaint = ArtifactRules.complaint(
        about: requirement.output, identifier: Packaging.identifier)
    {
        print("    \(complaint)")
    }

    print(layout.bundle.path)

case "submit":
    let certificates = try Certificates.onThisMachine(in: root)
    let profile = Submission.profile(under: root)
    let missing = Submission.missing(among: certificates, profile: profile)
    guard missing.isEmpty else {
        for absence in missing {
            print("\n==> \(absence.requirement.rawValue)")
            print(absence.requirement.howToGetIt)
        }
        fail("\(missing.count) thing(s) are not in place yet; nothing was built")
    }

    guard
        let application = certificates.identity(.application),
        let installer = certificates.identity(.installer),
        let profile,
        let team = Submission.team(of: application)
    else { fail("the certificates are there but could not be read") }

    let store: BundleLayout
    do {
        store = try Packaging(root: root).assemble(.release)
    } catch let refusal as Packaging.Refusal {
        fail(refusal.detail)
    }

    try FileManager.default.copyItem(
        at: profile, to: Submission.embeddedProfile(in: store.bundle))

    let rights = FileManager.default.temporaryDirectory
        .appendingPathComponent("ekranbildo-store-entitlements.plist")
    try Submission.entitlements(team: team, identifier: Packaging.identifier).write(to: rights)
    defer { try? FileManager.default.removeItem(at: rights) }

    let stamped = try Command.run(
        "/usr/bin/codesign",
        [
            "--force", "--sign", application,
            "--entitlements", rights.path,
            "--options", "runtime",
            store.bundle.path,
        ],
        in: root
    )
    guard stamped.status == 0 else { fail("could not sign:\n\(stamped.output)") }

    let package = root.appendingPathComponent(".build/\(Packaging.name).pkg")
    try? FileManager.default.removeItem(at: package)
    let wrapped = try Command.run(
        "/usr/bin/productbuild",
        Submission.productbuildArguments(
            bundle: store.bundle, package: package, identity: installer),
        in: root
    )
    guard wrapped.status == 0 else { fail("could not build the installer:\n\(wrapped.output)") }

    print(package.path)
    print("\nHand it over with `ekranbildo-dev upload`.")

case "upload":
    let account = try? AppStoreAccount.read(from: AppStoreAccount.beside(root))
    let key = account.flatMap(Upload.key(for:))
    let notReady = Upload.missing(account: account, key: key)
    guard notReady.isEmpty, let account else {
        for absence in notReady {
            print("\n==> \(absence.requirement.rawValue)")
            print(absence.requirement.howToGetIt)
        }
        fail("\(notReady.count) thing(s) are not in place yet; nothing was uploaded")
    }

    let built = try Command.run(
        try Toolchain.locate("swift").path(),
        ["run", "--package-path", "Tools", "ekranbildo-dev", "submit"],
        in: root
    )
    guard built.status == 0 else { fail("the package did not build:\n\(built.output)") }

    let bundled = root.appendingPathComponent(".build/\(Packaging.name).pkg")
    guard FileManager.default.fileExists(atPath: bundled.path) else {
        fail("the package was built but is not at \(bundled.path)")
    }

    print("uploading \(bundled.lastPathComponent) to App Store Connect")
    let handed = try Command.run(
        "/usr/bin/xcrun", Upload.arguments(package: bundled, account: account), in: root)
    print(handed.output.trimmingCharacters(in: .whitespacesAndNewlines))
    guard handed.status == 0 else { fail("App Store Connect would not take it") }
    print("    accepted; it will appear in App Store Connect once it finishes processing")

case "stage":
    guard let wanted = arguments.dropFirst().first else { fail("which stage?") }
    guard let stage = try checks.stages().first(where: { $0.name == wanted }) else {
        fail("no stage called '\(wanted)'; try `list`")
    }
    let result = StageResult(attempting: stage, in: Context(root: root))
    let trimmed = result.outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { print(trimmed) }
    print(result.verdict == .passed ? "    ok" : "    FAILED")
    exit(result.verdict == .passed ? 0 : 1)

case "check":
    let missing = Toolchain.missing(from: checks.required)
    guard missing.isEmpty else {
        fail("not on this machine: \(missing.joined(separator: ", "))")
    }

    let context = Context(root: root)
    var results: [StageResult] = []
    for stage in try checks.stages() {
        print("\n==> \(stage.name)")
        let result = StageResult(attempting: stage, in: context)
        results.append(result)

        let trimmed = result.outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { print(trimmed) }
        print(result.verdict == .passed ? "    ok" : "    FAILED")
    }

    let summary = RunSummary(results: results)
    print("")
    print(summary.report)
    exit(summary.succeeded ? 0 : 1)

default:
    fail("no such command '\(verb)'")
}
