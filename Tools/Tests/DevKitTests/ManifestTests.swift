@testable import DevKit
import Testing


@Suite("The manifest")
struct ManifestTests {

    private static let dump = """
        {
          "targets": [
            {"name": "A", "type": "regular", "dependencies": [{"byName": ["B", null]}]},
            {"name": "B", "type": "regular", "dependencies": []},
            {"name": "ATests", "type": "test",
             "dependencies": [{"byName": ["A", null]}, {"byName": ["B", null]}]},
            {"name": "C", "type": "regular",
             "dependencies": [{"product": ["Lib", "some-package", null, null]}]}
          ]
        }
        """

    @Test("Every target is read")
    func readsEveryTarget() throws {
        let manifest = try Manifest(dump: Self.dump)
        #expect(manifest.targets.map(\.name).sorted() == ["A", "ATests", "B", "C"])
    }

    @Test("A dependency by name is a dependency")
    func byNameDependency() throws {
        let manifest = try Manifest(dump: Self.dump)
        #expect(manifest.declared(by: "A") == ["B"])
    }

    @Test("A target with none has none")
    func noDependencies() throws {
        #expect(try Manifest(dump: Self.dump).declared(by: "B").isEmpty)
    }

    @Test("A product from another package is a dependency")
    func productDependency() throws {
        #expect(try Manifest(dump: Self.dump).declared(by: "C") == ["Lib"])
    }

    @Test("A target nobody declared has nothing")
    func unknownTarget() throws {
        #expect(try Manifest(dump: Self.dump).declared(by: "Nope").isEmpty)
    }

    @Test("A dump that is not a dump is refused")
    func rubbishIsRefused() {
        #expect(throws: (any Error).self) { try Manifest(dump: "not json") }
    }


    @Test("An import of a sibling that was not declared is a finding")
    func undeclaredImportIsAFinding() throws {
        let manifest = try Manifest(dump: Self.dump)
        let found = manifest.undeclared(
            imports: [Import(module: "EkranbildoThing", line: 3)], by: "A", in: "A/x.swift")
        #expect(found.count == 1)
        #expect(found[0].line == 3)
    }

    @Test("An import that was declared is not")
    func declaredImportIsFine() throws {
        let manifest = try Manifest(dump: Self.dump)
        #expect(
            manifest.undeclared(
                imports: [Import(module: "B", line: 1)], by: "A", in: "A/x.swift"
            ).isEmpty)
    }

    @Test("A system framework is not this rule's business")
    func systemFrameworksAreIgnored() throws {
        let manifest = try Manifest(dump: Self.dump)
        #expect(
            manifest.undeclared(
                imports: [Import(module: "Foundation", line: 1)], by: "A", in: "A/x.swift"
            ).isEmpty)
    }

    @Test("A module importing itself has not failed to declare anything")
    func ownModuleIsNotADependency() throws {
        let manifest = try Manifest(dump: Self.dump)
        #expect(
            manifest.undeclared(
                imports: [Import(module: "A", line: 1)], by: "A", in: "A/x.swift"
            ).isEmpty)
    }
}
