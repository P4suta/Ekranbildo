import AppKit
import EkranbildoApp
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoOverlay
import EkranbildoSemantics
import EkranbildoViews

@MainActor
final class CaptureSession {
    private var windows: [OverlayWindow] = []
    private var watching: Any?
    private var overlays: Lookup<ObjectIdentifier, OverlayView> = Lookup()
    private let assets: AssetStore
    private let capturer = ScreenCaptureKitCapturer()

    init(assets: AssetStore) {
        self.assets = assets
    }

    var finished: (@MainActor (Scene?, ScreenRect?) -> Void)?

    func begin() async {
        let frozen: ScreenCaptureKitCapturer.Freeze
        do {
            frozen = try await capturer.captureEveryDisplay()
        } catch {
            report(error)
            finished?(nil, nil)
            return
        }
        say(
            "froze \(frozen.screens.count) screen(s) in \(frozen.roundTrips) "
                + "round trip(s) to the system"
        )

        for capture in frozen.screens {
            let display = capture.geometry.display
            guard let screen = Self.screen(for: display) else {
                say("display \(display.displayID) has no NSScreen, so it gets no overlay")
                continue
            }
            present(
                FrozenScreen(
                    display: display, image: capture.image, windows: capture.windows),
                on: screen
            )
        }

        guard !windows.isEmpty else {
            say("no overlay went up, so there is nothing to choose with")
            finished?(nil, nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        takeTheKeyboard()
        watchForEvents()
    }

    private func learn(about frozen: FrozenScreen, for view: OverlayView) {
        let picture = frozen.image
        let display = frozen.display.displayID
        Task { [weak self, weak view] in
            let found = await Self.detected(in: picture)
            guard let view else { return }
            view.overlay.learned(found)
            view.needsDisplay = true
            self?.say("found \(found.count) thing(s) on display \(display)")
        }
    }

    nonisolated private static func detected(in picture: ImageBuffer) async -> [ScreenElement] {
        await Task.detached(priority: .userInitiated) {
            ElementDetector().detect(in: picture)
        }.value
    }

    private func watchForEvents() {
        watching = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp, .keyDown]
        ) { [weak self] event in
            let mine = self?.windows.first { $0.windowNumber == event.windowNumber }
            self?.say(
                "the application was handed \(event.type.rawValue) for window "
                    + "\(event.windowNumber), which is "
                    + (mine == nil ? "not an overlay" : "an overlay")
            )
            return event
        }
    }

    func dismiss() {
        if let watching { NSEvent.removeMonitor(watching) }
        watching = nil
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        overlays.removeAll()
    }

    private func present(_ frozen: FrozenScreen, on screen: NSScreen) {
        assets.put(frozen.image, as: Overlay.frozenName(of: frozen))

        let view = OverlayView(overlay: Overlay(frozen: frozen), assets: assets)
        view.arrived = { [weak self] what in self?.say(what) }
        view.drew = { [weak self] what in self?.say(what) }
        let window = OverlayWindow(view: view, screen: screen)
        window.received = { [weak self] what in self?.say(what) }
        view.send = { [weak self, weak view] event in
            guard let self, let view else { return }
            view.overlay = view.overlay.handle(event)
            if let outcome = view.overlay.outcome {
                self.chose(outcome, from: view.overlay.frozen)
            }
        }
        overlays[ObjectIdentifier(view)] = view
        windows.append(window)
        learn(about: frozen, for: view)
        window.orderFront(nil)
        say(
            "overlay for display \(frozen.display.displayID) at "
                + "\(Self.said(frozen.display.bounds)) is on a screen at "
                + "\(Self.said(screen.frame)), window now at "
                + "\(Self.said(window.frame)), key=\(window.isKeyWindow)"
        )
    }

    #if DEBUG
        private func writeAPictureOfTheOverlay(_ window: OverlayWindow) {
            guard let view = window.contentView,
                let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            else {
                say("there is nothing to take a picture of")
                return
            }
            view.cacheDisplay(in: view.bounds, to: representation)
            guard let data = representation.representation(using: .png, properties: [:]) else {
                say("the picture of the overlay could not be encoded")
                return
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("ekranbildo-overlay.png")
            do {
                try data.write(to: destination)
                say("what the overlay looks like is in \(destination.path)")
            } catch {
                say("could not write the picture of the overlay: \(error)")
            }
        }
    #endif

    private func takeTheKeyboard() {
        let pointer = NSEvent.mouseLocation
        let chosen = Overlay.screenUnder(
            Self.screenPoint(of: pointer),
            among: windows.map { ScreenRect($0.overlay.frozen.display.bounds) }
        )
        guard let chosen else { return }
        let window = windows[chosen]
        window.makeKeyAndOrderFront(nil)
        say("the keyboard was offered to the overlay on display \(window.overlay.frozen.display.displayID)")

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            let content =
                window.contentView.map { Self.said($0.frame) } ?? "none"
            let middle = NSPoint(
                x: window.frame.width * Self.middleOfTheScreen,
                y: window.frame.height * Self.middleOfTheScreen
            )
            let hit = window.contentView?.hitTest(middle)
            #if DEBUG
                self.writeAPictureOfTheOverlay(window)
            #endif
            self.say(
                "after the run loop turned: key=\(window.isKeyWindow), "
                    + "application active=\(NSApp.isActive), "
                    + "first responder is a view=\(window.firstResponder is OverlayView), "
                    + "content view is \(content), "
                    + "a click in the middle would reach \(hit.map { "\(type(of: $0))" } ?? "nothing"), "
                    + "window ignores the mouse=\(window.ignoresMouseEvents), "
                    + "alpha=\(window.alphaValue), level=\(window.level.rawValue), "
                    + "on the active space=\(window.isOnActiveSpace), "
                    + "window number=\(window.windowNumber), "
                    + "visible=\(window.isVisible), "
                    + "occlusion=\(window.occlusionState.contains(.visible) ? "showing" : "hidden")"
            )
        }
    }

    private static let middleOfTheScreen = 0.5

    private static func screenPoint(of pointer: NSPoint) -> ScreenPoint {
        let main = NSScreen.screens.first?.frame ?? .zero
        return ScreenPoint(x: Double(pointer.x), y: Double(main.maxY - pointer.y))
    }

    private static func said(_ rect: Rect) -> String {
        "(\(Int(rect.minX)), \(Int(rect.minY)), \(Int(rect.width))x\(Int(rect.height)))"
    }

    private static func said(_ rect: NSRect) -> String {
        said(
            Rect(
                x: Double(rect.origin.x),
                y: Double(rect.origin.y),
                width: Double(rect.width),
                height: Double(rect.height)
            ))
    }

    private func chose(_ outcome: OverlayOutcome, from frozen: FrozenScreen) {
        say("chosen: \(outcome)")
        dismiss()
        finished?(
            ChosenCapture.scene(of: outcome, in: frozen, assets: assets),
            ChosenCapture.region(of: outcome, in: frozen)
        )
    }

    private static func screen(for display: DisplayGeometry) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 == display.displayID
        }
    }

    private func report(_ error: any Error) {
        FileHandle.standardError.write(Data("ekranbildo: \(error)\n".utf8))
    }

    private func say(_ what: String) {
        FileHandle.standardError.write(Data("ekranbildo: capture: \(what)\n".utf8))
    }
}
