import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoObservability
import Foundation

public struct CaptureOptions: Sendable, Equatable {
    public let listsOnly: Bool
    public let displayID: UInt32?
    public let windowID: UInt32?
    public let pngOutput: String?
    public let reportOutput: String?

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        listsOnly = parsed.positional.contains(Subcommands.list)

        guard parsed.positional.allSatisfy({ $0 == Subcommands.list }) else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[0])'"
            )
        }

        displayID = try Self.identifier(parsed.value(of: "--display"), named: "--display")
        windowID = try Self.identifier(parsed.value(of: "--window"), named: "--window")
        pngOutput = parsed.value(of: "--png")
        reportOutput = parsed.value(of: "--report")

        guard displayID == nil || windowID == nil else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--display and --window ask for different pictures; give one"
            )
        }
    }

    static let knownFlags = ["--display", "--window", "--png", "--report"]

    private enum Subcommands {
        static let list = "list"
    }

    private static func identifier(_ text: String?, named flag: String) throws -> UInt32? {
        guard let text else { return nil }
        guard let value = UInt32(text) else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "\(flag) needs an identifier, got '\(text)'"
            )
        }
        return value
    }

    public func subject(displays: [DisplayGeometry]) throws -> CaptureSubject {
        if let windowID { return .window(WindowID(windowID)) }
        guard
            let display = displayID.flatMap({ id in displays.first { $0.displayID == id } })
                ?? displays.first
        else {
            throw CommandError(
                code: CommandError.unavailableDetector,
                detail: "no display is connected"
            )
        }
        return .display(display)
    }
}

public struct CaptureOutputs: Sendable, Equatable {
    public let listing: String
    public let png: [UInt8]?
    public let report: String?
}

public struct CaptureCommand: Sendable {
    private let capturer: any ScreenCapturing

    public init(capturer: any ScreenCapturing) {
        self.capturer = capturer
    }

    public func run(_ options: CaptureOptions) async throws -> CaptureOutputs {
        let permission = await capturer.permission()
        guard permission == .granted else {
            throw CommandError(
                code: CommandError.permissionMissing,
                detail: Self.explain(permission)
            )
        }

        let displays = try await capturer.displays()
        let windows = try await capturer.windows()
        let listing = Self.listing(displays: displays, windows: windows)

        guard !options.listsOnly else {
            return CaptureOutputs(listing: listing, png: nil, report: nil)
        }

        let capture = try await capturer.capture(try options.subject(displays: displays))
        let png = try ImageCodec.encodePNG(capture.image)

        return CaptureOutputs(
            listing: listing,
            png: options.pngOutput == nil ? nil : png,
            report: options.reportOutput == nil
                ? nil
                : try DetectCommand().run(
                    imageBytes: png,
                    options: DetectOptions(arguments: ["-", "--report", "-"])
                ).report
        )
    }

    public static func explain(_ permission: CapturePermission) -> String {
        switch permission {
        case .granted:
            "screen recording is granted"
        case .notDetermined:
            "screen recording has not been allowed yet; the first capture will ask"
        case .denied:
            """
            screen recording is turned off for this program. \
            Turn it on in System Settings, under Privacy & Security, Screen Recording.
            """
        case .grantedPendingRestart:
            """
            screen recording is allowed, but this program started before it was, \
            so it still cannot see anything. Start it again.
            """
        }
    }

    static func listing(displays: [DisplayGeometry], windows: WindowStack) -> String {
        let displayLines =
            displays
            .sorted { $0.displayID < $1.displayID }
            .map { display in
                """
                display \(display.displayID) \
                \(ScreenRect(display.bounds).canonicalText) \
                scale \(CanonicalText.rounded(display.backingScale, places: Precision.places)) \
                \(display.pixelWidth)x\(display.pixelHeight)px
                """
            }

        let windowLines = windows.onScreen
            .sorted { ($0.layer, $0.id.raw) < ($1.layer, $1.id.raw) }
            .map { window in
                """
                window \(window.id.raw) layer \(window.layer) \
                \(window.frame.canonicalText) \
                \(window.applicationName ?? "?") "\(window.describedName)"
                """
            }

        return (displayLines + windowLines).joined(separator: "\n")
    }

    private enum Precision {
        static let places = 2
    }
}
