import Foundation


public struct Manifest: Sendable {
    public struct Target: Sendable {
        public let name: String
        public let dependencies: [String]
    }

    public let targets: [Target]

    public init(dump: String) throws {
        let decoded = try JSONDecoder().decode(Dump.self, from: Data(dump.utf8))
        targets = decoded.targets.map {
            Target(name: $0.name, dependencies: $0.dependencies.compactMap(\.name))
        }
    }

    public static func read(at root: URL) throws -> Self {
        let swift = try Toolchain.locate("swift").path()
        let outcome = try Command.run(swift, ["package", "dump-package"], in: root)
        guard outcome.status == 0 else {
            throw Command.Failure(description: "could not read the manifest: \(outcome.output)")
        }
        return try Self(dump: outcome.output)
    }

    public func declared(by target: String) -> [String] {
        targets.first { $0.name == target }?.dependencies ?? []
    }

    public func undeclared(imports: [Import], by target: String, in path: String) -> [Finding] {
        let own = Set(declared(by: target))
        return imports.compactMap { reached in
            guard reached.module.hasPrefix(Self.ownPrefix), reached.module != target else {
                return nil
            }
            guard !own.contains(reached.module) else { return nil }
            return Finding(
                path: path,
                line: reached.line,
                advice: "\(target) imports \(reached.module) without declaring it. A dependency "
                    + "it did not ask for is somebody else's decision, and it goes the day they "
                    + "change theirs."
            )
        }
    }

    static let ownPrefix = "Ekranbildo"


    private struct Dump: Decodable {
        let targets: [Entry]

        struct Entry: Decodable {
            let name: String
            let dependencies: [Dependency]
        }

        struct Dependency: Decodable {
            let name: String?

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: AnyKey.self)
                for key in container.allKeys {
                    if let pair = try? container.decode([String?].self, forKey: key),
                        let first = pair.first ?? nil
                    {
                        name = first
                        return
                    }
                }
                name = nil
            }
        }

        struct AnyKey: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }
    }
}
