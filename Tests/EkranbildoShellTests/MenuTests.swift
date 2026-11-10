import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoHotkeys
import EkranbildoLibrary
@testable import EkranbildoShell
import EkranbildoTestKit
import Testing

@Suite("Menu")
struct MenuTests {

    private func menu(
        _ permission: CapturePermission,
        recording: Bool = false,
        library: Library = Library()
    ) -> Menu {
        Menu(permission: permission, isRecording: recording, library: library)
    }

    private func entry(_ index: Int) -> LibraryEntry {
        LibraryEntry(
            id: CaptureID(UInt32(index)),
            takenAt: Timestamp.seconds(Double(index)),
            image: ImageRef(contentHash: "shot-\(index)", pixelWidth: 10, pixelHeight: 10),
            canvas: Size(width: 10, height: 10),
            source: .region
        )
    }

    @Test("With permission, capturing is offered")
    func offersCapture() {
        let items = menu(.granted).items
        #expect(items.contains { $0.command == .captureRegion })
        #expect(items.contains { $0.command == .captureWindow })
        #expect(items.contains { $0.command == .captureScreen })
        #expect(items.allSatisfy { $0.isEnabled })
    }

    @Test("Each capture item shows the key combination that does it")
    func showsShortcuts() throws {
        let region = try #require(menu(.granted).items.first { $0.command == .captureRegion })
        #expect(region.shortcut == Shortcut.Defaults.captureRegion)
        #expect(region.title.isEmpty == false)
    }

    @Test(
        "Without permission, capturing is offered but not available",
        arguments: [CapturePermission.notDetermined, .denied, .grantedPendingRestart]
    )
    func disablesCapture(permission: CapturePermission) {
        let items = menu(permission).items
        let capture = items.filter { $0.command.needsScreen }
        #expect(!capture.isEmpty)
        #expect(capture.allSatisfy { !$0.isEnabled })
    }

    @Test("Permission granted but not yet in effect says to restart")
    func saysToRestart() throws {
        let explanation = try #require(menu(.grantedPendingRestart).explanation)
        #expect(explanation.lowercased().contains("again"))
        #expect(!explanation.lowercased().contains("settings"))
    }

    @Test("Permission refused says where to turn it on")
    func saysWhereToTurnItOn() throws {
        let explanation = try #require(menu(.denied).explanation)
        #expect(explanation.contains("Settings"))
    }

    @Test("Before anybody is asked, the first capture will ask")
    func notYetAsked() throws {
        let explanation = try #require(menu(.notDetermined).explanation)
        #expect(explanation.lowercased().contains("ask"))
    }

    @Test("With permission there is nothing to explain")
    func nothingToExplain() {
        #expect(menu(.granted).explanation == nil)
    }

    @Test("Recording is offered when nothing is being recorded")
    func offersRecording() {
        #expect(menu(.granted).items.contains { $0.command == .startRecording })
    }

    @Test("While recording, stopping is what is offered")
    func offersStopping() {
        let items = menu(.granted, recording: true).items
        #expect(items.contains { $0.command == .stopRecording })
        #expect(!items.contains { $0.command == .startRecording })
    }

    @Test("While recording, capturing is not available")
    func noCaptureWhileRecording() {
        let items = menu(.granted, recording: true).items
        #expect(
            items.filter { $0.command.needsScreen && $0.command != .stopRecording }
                .allSatisfy { !$0.isEnabled })
    }

    @Test("Recent captures are offered, newest first")
    func offersRecent() {
        var library = Library()
        for index in 0..<3 { _ = library.add(entry(index)) }
        let recent = menu(.granted, library: library).items.compactMap(\.command.capture)
        #expect(recent == [CaptureID(2), CaptureID(1), CaptureID(0)])
    }

    @Test("Only a few recent captures are offered")
    func limitsRecent() {
        var library = Library()
        for index in 0..<50 { _ = library.add(entry(index)) }

        let recent = menu(.granted, library: library).items.compactMap(\.command.capture)
        #expect(recent.count == Menu.Defaults.recentShown)
    }

    @Test("With nothing captured yet, nothing recent is offered")
    func noRecent() {
        #expect(menu(.granted).items.compactMap(\.command.capture).isEmpty)
    }

    @Test(
        "Settings and quitting are always available",
        arguments: [
            CapturePermission.granted, .denied, .notDetermined, .grantedPendingRestart,
        ]
    )
    func alwaysAvailable(permission: CapturePermission) {
        for recording in [false, true] {
            let items = menu(permission, recording: recording).items
            for command in [MenuCommand.openSettings, .quit] {
                let item = items.first { $0.command == command }
                #expect(
                    item?.isEnabled == true,
                    "\(command) is unavailable when \(permission) and recording is \(recording)"
                )
            }
        }
    }

    @Test("The menu is the same every time it is opened")
    func reproducible() {
        var library = Library()
        for index in 0..<4 { _ = library.add(entry(index)) }
        #expect(isReproducible { menu(.granted, library: library).items })
    }
}
