import Foundation

public enum LicenceRules {
    public static let offered = ["LICENSE-APACHE", "LICENSE-MIT"]

    public static func findings(readme: String, files: Set<String>) -> [Finding] {
        offered.compactMap { licence in
            guard !files.contains(licence) || !readme.contains(licence) else { return nil }
            return Finding(path: "README.md", line: 1, advice: advice(for: licence))
        }
    }

    static func advice(for licence: String) -> String {
        "\(licence) has to be both a file anybody can read and a licence the README "
            + "offers. One without the other is a promise nobody can act on: a file "
            + "nobody is pointed at, or an offer of terms nobody can see."
    }

    public static func check(in root: URL) throws -> [Finding] {
        let readme =
            (try? String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8))
            ?? ""
        let present = offered.filter {
            FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path)
        }
        return findings(readme: readme, files: Set(present))
    }
}
