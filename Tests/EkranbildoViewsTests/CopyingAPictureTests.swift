import AppKit
import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
@testable import EkranbildoViews
import Testing

@Suite("Copying a picture", .serialized)
@MainActor
struct CopyingAPictureTests {

    private static func scene() -> Scene {
        SceneLibrary.sampleAnnotated
    }

    private func bytes(of scene: Scene) throws -> [UInt8] {
        try Clipboard.png(of: scene, assets: nil, scale: 1)
    }

    @Test("A picture becomes bytes somebody could paste")
    func becomesBytes() throws {
        let made = try bytes(of: Self.scene())
        #expect(!made.isEmpty)
        #expect(made.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("What is put on the pasteboard is on the pasteboard")
    func reachesThePasteboard() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))

        let read = try #require(board.data(forType: .png))
        #expect(!read.isEmpty)
        #expect(Array(read).starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("What is pasted can be read as a picture, not only as a file")
    func readableAsAPicture() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))

        #expect(NSImage(pasteboard: board) != nil)
    }

    @Test("Putting one picture on replaces the last")
    func replaces() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        board.clearContents()
        board.setString("something else", forType: .string)

        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))
        #expect(board.string(forType: .string) == nil)
        #expect(board.data(forType: .png) != nil)
    }

    @Test("A picture is one thing on the pasteboard, the way the system puts one there")
    func oneItem() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))

        #expect(board.pasteboardItems?.count == 1)
    }

    @Test("Anything that asks for a picture in another shape is given one")
    func convertedOnDemand() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))

        #expect(board.canReadObject(forClasses: [NSImage.self]))
        #expect(board.data(forType: .tiff) != nil)
    }

    @Test("Copying says whether it worked rather than hoping it did")
    func saysWhetherItWorked() throws {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(Clipboard.put(try bytes(of: Self.scene()), on: board))
    }

    @Test("Copying nothing is not reported as having worked")
    func nothingIsNotSuccess() {
        let board = NSPasteboard(name: .init(rawValue: "ekranbildo.test.\(UUID().uuidString)"))
        #expect(!Clipboard.put([], on: board))
    }

    @Test("The same picture copies to the same bytes")
    func reproducible() throws {
        let once = try bytes(of: Self.scene())
        let again = try bytes(of: Self.scene())
        #expect(once == again)
    }
}
