import CoreGraphics
import CoreMedia
import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoImaging
import Foundation
import ScreenCaptureKit

public struct Aim {
    public let filter: SCContentFilter
    public let geometry: CaptureGeometry

    public init(filter: SCContentFilter, geometry: CaptureGeometry) {
        self.filter = filter
        self.geometry = geometry
    }
}

public struct ScreenCaptureKitCapturer: ScreenCapturing {
    private let includesShadows: Bool
    private let includesCursor: Bool

    public init(includesShadows: Bool = false, includesCursor: Bool = false) {
        self.includesShadows = includesShadows
        self.includesCursor = includesCursor
    }

    public var capturesShadows: Bool { includesShadows }
    public var capturesCursor: Bool { includesCursor }

    public func permission() async -> CapturePermission {
        guard CGPreflightScreenCaptureAccess() else { return .notDetermined }
        guard let content = try? await shareableContent() else { return .denied }
        return Self.seesOtherApplications(content) ? .granted : .grantedPendingRestart
    }

    static func seesOtherApplications(_ content: SCShareableContent) -> Bool {
        let ownProcess = ProcessInfo.processInfo.processIdentifier
        return content.windows.contains { $0.owningApplication?.processID != ownProcess }
    }

    private func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: false
            )
        } catch {
            throw CaptureError(
                code: CaptureError.permissionMissing,
                detail: "the system would not say what is on the screen: \(error)"
            )
        }
    }

    public func displays() async throws -> [DisplayGeometry] {
        let content = try await shareableContent()
        return content.displays.map(Self.geometry(of:))
    }

    static func geometry(of display: SCDisplay) -> DisplayGeometry {
        let bounds = CGDisplayBounds(display.displayID)
        return DisplayGeometry(
            displayID: display.displayID,
            bounds: Rect(
                x: Double(bounds.origin.x),
                y: Double(bounds.origin.y),
                width: Double(bounds.width),
                height: Double(bounds.height)
            ),
            backingScale: Self.backingScale(of: display.displayID)
        )
    }

    static func backingScale(of displayID: CGDirectDisplayID) -> Double {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else {
            return Defaults.backingScale
        }
        return backingScale(points: mode.width, pixels: mode.pixelWidth)
    }

    static func backingScale(points: Int, pixels: Int) -> Double {
        guard points > 0, pixels > 0 else { return Defaults.backingScale }
        return Double(pixels) / Double(points)
    }

    public func windows() async throws -> WindowStack {
        WindowStack(windows: try await shareableContent().windows.map(Self.descriptor(of:)))
    }

    static func descriptor(of window: SCWindow) -> WindowDescriptor {
        WindowDescriptor(
            id: WindowID(window.windowID),
            title: window.title,
            applicationName: window.owningApplication?.applicationName,
            bundleIdentifier: window.owningApplication?.bundleIdentifier,
            frame: ScreenRect(
                x: Double(window.frame.origin.x),
                y: Double(window.frame.origin.y),
                width: Double(window.frame.width),
                height: Double(window.frame.height)
            ),
            isOnScreen: window.isOnScreen,
            layer: window.windowLayer
        )
    }

    public func frameSource(
        for subject: CaptureSubject,
        scale: Double = Recording.scale
    ) async throws -> StreamFrameSource {
        let content = try await shareableContent()
        let aim = try Self.filter(for: subject, in: content)
        let filter = aim.filter
        let geometry = aim.geometry

        let configuration = SCStreamConfiguration()
        configuration.width = Int((geometry.sceneSize.width * scale).rounded())
        configuration.height = Int((geometry.sceneSize.height * scale).rounded())
        configuration.scalesToFit = false
        configuration.showsCursor = includesCursor
        configuration.ignoreShadowsSingleWindow = !includesShadows
        configuration.ignoreShadowsDisplay = !includesShadows
        configuration.captureResolution = .best
        configuration.minimumFrameInterval = CMTime(
            value: 1, timescale: CMTimeScale(Recording.framesPerSecond))
        configuration.queueDepth = Recording.queueDepth

        return StreamFrameSource(
            filter: filter,
            configuration: configuration,
            display: geometry.display
        )
    }

    public enum Recording {
        public static let framesPerSecond = 30
        public static let queueDepth = 8
        public static let scale: Double = 1
    }

    public func recordingGeometry(
        for subject: CaptureSubject,
        scale: Double = Recording.scale
    ) async throws -> CaptureGeometry {
        let full = try Self.filter(for: subject, in: try await shareableContent()).geometry
        return CaptureGeometry(
            display: DisplayGeometry(
                displayID: full.display.displayID,
                bounds: full.display.bounds,
                backingScale: scale
            ),
            regionInScreen: full.regionInScreen
        )
    }

    public func capture(_ subject: CaptureSubject) async throws -> ScreenCapture {
        try await capture(subject, in: try await shareableContent())
    }

    public func captureEveryDisplay() async throws -> Freeze {
        let content = try await shareableContent()
        var frozen: [ScreenCapture] = []
        for display in content.displays {
            frozen.append(
                try await capture(.display(Self.geometry(of: display)), in: content))
        }
        return Freeze(screens: frozen, roundTrips: 1)
    }

    public struct Freeze: Sendable {
        public let screens: [ScreenCapture]
        public let roundTrips: Int

        public init(screens: [ScreenCapture], roundTrips: Int) {
            self.screens = screens
            self.roundTrips = roundTrips
        }
    }

    private func capture(
        _ subject: CaptureSubject,
        in content: SCShareableContent
    ) async throws -> ScreenCapture {
        let stack = WindowStack(windows: content.windows.map(Self.descriptor(of:)))
        let aim = try Self.filter(for: subject, in: content)
        let filter = aim.filter
        let geometry = aim.geometry

        let configuration = SCStreamConfiguration()
        configuration.width = geometry.pixelWidth
        configuration.height = geometry.pixelHeight
        configuration.scalesToFit = false
        configuration.showsCursor = includesCursor
        configuration.ignoreShadowsSingleWindow = !includesShadows
        configuration.ignoreShadowsDisplay = !includesShadows
        configuration.captureResolution = .best

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw CaptureError(
                code: CaptureError.captureFailed,
                detail: "the system would not take the picture: \(error)"
            )
        }

        return ScreenCapture(
            image: try ImageCodec.buffer(from: image),
            geometry: geometry,
            windows: stack
        )
    }

    static func filter(
        for subject: CaptureSubject,
        in content: SCShareableContent
    ) throws -> Aim {
        switch subject {
        case .display(let wanted):
            let display = try Self.display(wanted.displayID, in: content)
            return Aim(
                filter: SCContentFilter(display: display, excludingWindows: []),
                geometry: CaptureGeometry(fullDisplay: Self.geometry(of: display))
            )

        case .region(let wanted, let region):
            let display = try Self.display(wanted.displayID, in: content)
            return Aim(
                filter: SCContentFilter(display: display, excludingWindows: []),
                geometry: CaptureGeometry(
                    display: Self.geometry(of: display),
                    regionInScreen: region.raw
                )
            )

        case .window(let id):
            guard let window = content.windows.first(where: { $0.windowID == id.raw }) else {
                throw CaptureError(
                    code: CaptureError.subjectGone,
                    detail: "window \(id.raw) is not on the screen any more"
                )
            }
            let descriptor = Self.descriptor(of: window)
            let display =
                content.displays
                .first { CGDisplayBounds($0.displayID).intersects(window.frame) }
                .map(Self.geometry(of:))
                ?? DisplayGeometry(
                    displayID: 0,
                    bounds: descriptor.frame.raw,
                    backingScale: Defaults.backingScale
                )
            return Aim(
                filter: SCContentFilter(desktopIndependentWindow: window),
                geometry: CaptureGeometry(display: display, regionInScreen: descriptor.frame.raw)
            )
        }
    }

    private static func display(_ id: UInt32, in content: SCShareableContent) throws -> SCDisplay {
        guard let display = content.displays.first(where: { $0.displayID == id }) else {
            throw CaptureError(
                code: CaptureError.subjectGone,
                detail: "display \(id) is not connected any more"
            )
        }
        return display
    }

    enum Defaults {
        static let backingScale: Double = 1
    }
}
