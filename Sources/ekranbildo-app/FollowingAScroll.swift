import AppKit
import EkranbildoApp
import EkranbildoContracts
import EkranbildoCore
import EkranbildoGeometry
import EkranbildoStitch
import EkranbildoViews

extension Shell {
    func followTheScroll(_ region: ScreenRect) {
        guard let display = Self.display(under: region) else {
            say("no screen holds that region, so there is nothing to follow")
            apply(.dismiss)
            return
        }
        let running = ScrollSessionRunner(display: display, region: region)
        scrolling = running
        running.saw = { [weak self] seen, advice in
            self?.apply(.scrolled(seen: seen, advice: advice))
            self?.progress?.show(seen: seen, advice: advice)
        }
        running.failed = { [weak self] said in
            self?.say("the scroll could not be followed: \(said)")
            self?.apply(.dismiss)
        }
        progress = ScrollProgressWindowController(
            finish: { [weak self] in self?.apply(.finishScrolling) },
            cancel: { [weak self] in self?.apply(.dismiss) }
        )
        progress?.showWindow(nil)
        bringForward()
        running.begin()
    }

    func joinTheScroll() {
        defer { endScrolling() }
        guard let running = scrolling else { return }
        running.stop()
        do {
            let joined = try running.joined()
            say(
                "joined \(running.frames.count) frame(s) into \(joined.image.height) rows, "
                    + "\(joined.uncertainJoins.count) of them uncertain"
            )
            let reference = assets.put(joined.image)
            apply(
                .captured(
                    Scene(
                        canvas: SceneRect(
                            x: 0,
                            y: 0,
                            width: Double(joined.image.width),
                            height: Double(joined.image.height)
                        ),
                        background: reference,
                        annotations: [],
                        style: .standard
                    ),
                    at: Self.now()
                )
            )
        } catch {
            say("the frames could not be joined: \(error)")
        }
    }

    func endScrolling() {
        scrolling?.stop()
        scrolling = nil
        progress?.close()
        progress = nil
    }

    static func display(under region: ScreenRect) -> DisplayGeometry? {
        NSScreen.screens.lazy.compactMap { screen -> DisplayGeometry? in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            guard let id = number as? UInt32 else { return nil }
            let bounds = CGDisplayBounds(id)
            let geometry = DisplayGeometry(
                displayID: id,
                bounds: Rect(
                    x: Double(bounds.origin.x),
                    y: Double(bounds.origin.y),
                    width: Double(bounds.width),
                    height: Double(bounds.height)
                ),
                backingScale: Double(screen.backingScaleFactor)
            )
            return geometry.bounds.intersection(region.raw) == nil ? nil : geometry
        }.first
    }
}
