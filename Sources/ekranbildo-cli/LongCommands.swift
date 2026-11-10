import AVFoundation
import EkranbildoCLI
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoRecord
import EkranbildoTimeline
import Foundation

func runRecord(_ options: RecordOptions) async throws {
    let capturer = ScreenCaptureKitCapturer()
    let permission = await capturer.permission()
    guard permission == .granted else {
        fail(CaptureCommand.explain(permission))
    }

    let displays = try await capturer.displays()
    guard
        let display = options.displayID.flatMap({ id in displays.first { $0.displayID == id } })
            ?? displays.first
    else {
        fail("no display is connected")
    }

    let subject = CaptureSubject.display(display)
    let source = try await capturer.frameSource(for: subject, scale: options.scale)
    let geometry = try await capturer.recordingGeometry(for: subject, scale: options.scale)

    Task {
        try? await Task.sleep(for: .seconds(options.seconds))
        source.stop()
    }

    let run = try await SourceRecorder(geometry: geometry).record(from: source)
    let outputs = try RecordCommand()
        .describe(run.recording, assets: run.assets, options: options)

    print(outputs.summary)

    if let path = options.summaryOutput { try write(outputs.summary, to: path) }
    if let directory = options.framesDirectory {
        let url = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for frame in outputs.frames {
            try Data(frame.png).write(to: url.appendingPathComponent(frame.name))
        }
        try write(outputs.timings, to: url.appendingPathComponent("timings.txt").path)
        try write(outputs.cursor, to: url.appendingPathComponent("cursor.json").path)
    }
}

func runRenderVideo(_ options: RenderVideoOptions) async throws {
    let directory = URL(fileURLWithPath: options.input)
    let files = try FileManager.default
        .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    let source = try files.map { url in
        try ImageCodec.decode([UInt8](try Data(contentsOf: url))).image
    }

    var events: [CameraEvent] = []
    var overrides: [CameraOverride] = []
    if let path = options.events {
        let json = try Data(contentsOf: URL(fileURLWithPath: path))
        let input = try JSONDecoder().decode(CameraInput.self, from: json)
        events = input.events
        overrides = input.overrides
    }

    let timingsFile = directory.appendingPathComponent("timings.txt")
    let timings: [Timestamp] =
        (try? String(contentsOf: timingsFile, encoding: .utf8))?
        .split(separator: "\n")
        .compactMap { line in
            line.split(separator: " ").last.flatMap(Double.init).map(Timestamp.seconds)
        } ?? []

    let cursorFile = directory.appendingPathComponent("cursor.json")
    let cursor = (try? Data(contentsOf: cursorFile))
        .flatMap { try? JSONDecoder().decode(RecordedCursor.self, from: $0) }
        .map { CursorTrack(recorded: $0.samples, geometry: $0.geometry) }

    let input = RenderVideoInput(
        source: source,
        events: events,
        timings: timings,
        cursor: cursor,
        overrides: overrides
    )

    if let directory = options.framesOutput {
        let url = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let rendered = try RenderVideoCommand().frames(input, options: options)
        for (index, frame) in rendered.frames.enumerated() {
            try Data(try ImageCodec.encodePNG(frame.image))
                .write(to: url.appendingPathComponent(RecordCommand.frameName(index)))
        }
    }

    let outputs = try await RenderVideoCommand().write(
        input,
        options: options,
        to: options.videoOutput.map { URL(fileURLWithPath: $0) },
        gif: options.gifOutput.map { URL(fileURLWithPath: $0) }
    )

    print("frames \(outputs.frameCount) \(outputs.width)x\(outputs.height)")
    print(outputs.keyframes)

    if let path = options.keyframesOutput { try write(outputs.keyframes, to: path) }
}
