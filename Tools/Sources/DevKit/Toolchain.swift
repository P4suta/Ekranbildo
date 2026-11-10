import Foundation


public enum Toolchain {
    public struct NotFound: Error, CustomStringConvertible {
        public let name: String
        public var description: String { "\(name) is not on the path" }
    }

    public struct Located: Sendable {
        private let url: URL

        init(url: URL) {
            self.url = url
        }

        public func path() -> String { url.path }
    }

    public static func locate(_ name: String) throws -> Located {
        let outcome = try Command.run(
            "/usr/bin/env", ["which", name], in: URL(fileURLWithPath: "/"))
        let found = outcome.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard outcome.status == 0, !found.isEmpty else { throw NotFound(name: name) }
        return Located(url: URL(fileURLWithPath: found))
    }

    public static func missing(from names: [String]) -> [String] {
        names.filter { (try? locate($0)) == nil }
    }
}
