import EkranbildoContracts
import EkranbildoCore
import EkranbildoEncode
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoObservability
import EkranbildoRender
import EkranbildoRenderCoreGraphics
import EkranbildoTimeline
import Foundation

public struct RenderVideoOptions: Sendable, Equatable {
    public let input: String
    public let events: String?
    public let videoOutput: String?
    public let keyframesOutput: String?
    public let gifOutput: String?
    public let framesOutput: String?
    public let framesPerSecond: Int

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)
        guard let input = parsed.positional.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "a directory of frames is required"
            )
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }
        self.input = input
        events = parsed.value(of: "--events")
        videoOutput = parsed.value(of: "--video")
        keyframesOutput = parsed.value(of: "--keyframes")
        gifOutput = parsed.value(of: "--gif")
        framesOutput = parsed.value(of: "--frames")

        if let text = parsed.value(of: "--fps") {
            guard let value = Int(text), value > 0 else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--fps needs a positive whole number, got '\(text)'"
                )
            }
            framesPerSecond = value
        } else {
            framesPerSecond = EncodeSettings.Defaults.framesPerSecond
        }
    }

    static let knownFlags = [
        "--events", "--video", "--keyframes", "--fps", "--frames", "--gif",
    ]
}

public struct RenderVideoOutputs: Sendable, Equatable {
    public let keyframes: String
    public let frameCount: Int
    public let width: Int
    public let height: Int
}

public struct RenderVideoInput: Sendable {
    public let source: [ImageBuffer]
    public let events: [CameraEvent]
    public let timings: [Timestamp]
    public let cursor: CursorTrack?
    public let overrides: [CameraOverride]

    public init(
        source: [ImageBuffer],
        events: [CameraEvent] = [],
        timings: [Timestamp] = [],
        cursor: CursorTrack? = nil,
        overrides: [CameraOverride] = []
    ) {
        self.source = source
        self.events = events
        self.timings = timings
        self.cursor = cursor
        self.overrides = overrides
    }
}

public struct RenderVideoCommand: Sendable {
    private let measurer: any TextMeasuring
    private let heldFrameLimit: Int
    private let pixelBudget: Int

    public init(
        measurer: any TextMeasuring = TabulatedTextMeasurer.uniform(),
        heldFrameLimit: Int = Limits.heldFrames,
        pixelBudget: Int = Limits.pixels
    ) {
        self.measurer = measurer
        self.heldFrameLimit = max(0, heldFrameLimit)
        self.pixelBudget = max(1, pixelBudget)
    }

    public enum Limits {
        public static let heldFrames = 36_000

        public static let pixels = 2_000_000_000
    }

    public func frames(
        _ input: RenderVideoInput,
        options: RenderVideoOptions
    ) throws -> RenderedRun {
        let plan = try plan(input, options: options)

        let pixels = plan.schedule.count * Int(plan.frame.raw.width * plan.frame.raw.height)
        guard pixels <= pixelBudget else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail:
                    "\(plan.schedule.count) frames of "
                    + "\(Int(plan.frame.raw.width))x\(Int(plan.frame.raw.height)) is "
                    + "\(pixels) pixels, which is more memory than this will take at once "
                    + "(the limit is \(pixelBudget))"
            )
        }

        var rendered: [TimedFrame] = []
        rendered.reserveCapacity(plan.schedule.count)
        for index in 0..<plan.schedule.count {
            rendered.append(try render(index, of: plan, from: input))
        }
        return RenderedRun(frames: rendered, path: plan.path)
    }

    struct Plan: Sendable {
        let schedule: [ScheduledFrame]
        let path: CameraPath
        let frame: SceneRect
    }

    func plan(_ input: RenderVideoInput, options: RenderVideoOptions) throws -> Plan {
        guard let first = input.source.first else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "there are no frames to render"
            )
        }

        let frame = SceneRect(
            x: 0, y: 0, width: Double(first.width), height: Double(first.height))
        let interval = 1.0 / Double(options.framesPerSecond)
        let moments =
            input.timings.count == input.source.count
            ? input.timings
            : (0..<input.source.count).map { Timestamp.seconds(Double($0) * interval) }

        let schedule = try Self.schedule(
            moments: moments,
            cursor: input.cursor,
            framesPerSecond: options.framesPerSecond,
            holdingAtMost: heldFrameLimit
        )

        return Plan(
            schedule: schedule,
            path: CameraPathSolver().solve(
                events: input.events,
                frame: frame,
                duration: schedule.last?.at ?? moments.last ?? .zero,
                overrides: input.overrides
            ),
            frame: frame
        )
    }

    func render(_ index: Int, of plan: Plan, from input: RenderVideoInput) throws -> TimedFrame {
        let entry = plan.schedule[index]
        let view = plan.path.view(at: entry.at) ?? plan.frame
        let cropped = Self.cropped(input.source[entry.picture], to: view, of: plan.frame)
        return TimedFrame(
            image: try drawn(input.cursor, at: entry.at, over: cropped, in: view),
            at: entry.at
        )
    }

    private func drawn(
        _ cursor: CursorTrack?,
        at moment: Timestamp,
        over picture: ImageBuffer,
        in view: SceneRect
    ) throws -> ImageBuffer {
        guard let pointer = cursor?.cursor(at: moment) else { return picture }

        let scene = Scene(
            canvas: view, background: nil, annotations: [], style: .standard, cursor: pointer)
        let list = DrawListBuilder(measurer: measurer, colorSpace: picture.colorSpace).build(scene)
        guard !list.commands.isEmpty else { return picture }

        return try CoreGraphicsRenderer().render(list, over: picture).bitmap.imageBuffer
    }

    @discardableResult
    public func write(
        _ input: RenderVideoInput,
        options: RenderVideoOptions,
        to url: URL?,
        gif: URL? = nil
    ) async throws -> RenderVideoOutputs {
        let plan = try plan(input, options: options)
        guard !plan.schedule.isEmpty else {
            throw CommandError(
                code: CommandError.missingInput,
                detail: "there are no frames to render"
            )
        }

        if let url {
            let first = try render(0, of: plan, from: input)
            let settings = EncodeSettings(
                width: first.image.width,
                height: first.image.height,
                framesPerSecond: options.framesPerSecond
            )
            var index = 0
            _ = try await VideoWriter(settings: settings).write(to: url) {
                guard index < plan.schedule.count else { return nil }
                defer { index += 1 }
                return index == 0 ? first : try render(index, of: plan, from: input)
            }
        }

        if let gif {
            try Data(GIFWriter().write(Self.shown(try frames(input, options: options).frames)))
                .write(to: gif)
        }

        let size = try render(0, of: plan, from: input).image
        return RenderVideoOutputs(
            keyframes: CameraReportText.of(plan.path),
            frameCount: plan.schedule.count,
            width: size.width,
            height: size.height
        )
    }

    static func shown(_ frames: [TimedFrame]) -> [HeldFrame] {
        TimedFrame.held(frames)
    }
}

enum CameraReportText {
    static func of(_ path: CameraPath) -> String {
        path.keyframes
            .map {
                "\(CanonicalText.rounded($0.at.seconds, places: Precision.time))s "
                    + $0.view.canonicalText
            }
            .joined(separator: "\n")
    }

    private enum Precision {
        static let time = 3
    }
}

public struct RenderedRun: Sendable {
    public let frames: [TimedFrame]
    public let path: CameraPath

    public init(frames: [TimedFrame], path: CameraPath) {
        self.frames = frames
        self.path = path
    }
}
