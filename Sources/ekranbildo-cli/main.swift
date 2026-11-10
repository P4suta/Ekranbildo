import EkranbildoCLI
import EkranbildoCapture
import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoSemantics
import EkranbildoSignposts
import EkranbildoVision
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

let signposts = Signposting.emitter(environment: Lookup(ProcessInfo.processInfo.environment))

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ekranbildo-cli: \(message)\n".utf8))
    exit(1)
}

func write(_ text: String, to path: String) throws {
    try (text + "\n").write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
}

func shell(_ line: String) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", line]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(bytes: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

guard !arguments.isEmpty, arguments.first != "--help", arguments.first != "-h" else {
    print(usage)
    #if EKRANBILDO_TESTHOOKS
        print(hooksUsage)
    #endif
    exit(arguments.isEmpty ? 1 : 0)
}

#if EKRANBILDO_TESTHOOKS
    if arguments.first == "hooks" {
        do {
            try serveHooks(Array(arguments.dropFirst()))
        } catch {
            fail("\(error)")
        }
    }
#endif

do {
    switch try Command(arguments: arguments) {
    case .icon(let options):
        let outputs = try IconCommand().run()
        let directory = URL(fileURLWithPath: options.directory)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        for picture in outputs.pngs {
            try Data(picture.png)
                .write(to: directory.appendingPathComponent(picture.name))
        }
        print("wrote \(outputs.pngs.count) picture(s) to \(options.directory)")

    case .render(let options):
        let sceneJSON = try String(contentsOfFile: options.input, encoding: .utf8)
        let outputs = try RenderCommand(signposts: signposts)
            .run(sceneJSON: sceneJSON, options: options)

        if let path = options.pngOutput, let png = outputs.png {
            try Data(png).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.svgOutput, let svg = outputs.svg { try write(svg, to: path) }
        if let path = options.reportOutput, let report = outputs.report {
            try write(report, to: path)
        }
        if let path = options.traceOutput, let trace = outputs.trace { try write(trace, to: path) }
        if let path = options.bundleOutput, let bundle = outputs.bundle {
            try write(bundle, to: path)
        }

    case .corpus(let options):
        let directory = URL(fileURLWithPath: options.input)
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let scenes = try files.map { url in
            CorpusInput(
                name: url.deletingPathExtension().lastPathComponent,
                json: try String(contentsOf: url, encoding: .utf8)
            )
        }
        let outputs = CorpusCommand().run(scenes: scenes)

        if let path = options.sheetOutput { try write(outputs.sheet, to: path) }
        if let path = options.scoreboardOutput { try write(outputs.scoreboard, to: path) }

        if outputs.failureCount > 0 {
            fail("\(outputs.failureCount) of \(scenes.count) scenes failed")
        }

    case .detect(let options):
        let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: options.input)))
        let outputs = try DetectCommand(
            providers: [
                .vision: VisionSemanticProvider(),
                .all: CombinedSemanticProvider([
                    RegionSemanticProvider(), VisionSemanticProvider(),
                ]),
            ]
        ).run(imageBytes: bytes, options: options)

        if let path = options.elementsOutput, let elements = outputs.elements {
            try write(elements, to: path)
        }
        if let path = options.reportOutput, let report = outputs.report {
            try write(report, to: path)
        }
        if let path = options.snapshotOutput, let snapshot = outputs.snapshot {
            try write(snapshot, to: path)
        }

    case .capture(let options):
        let outputs = try await CaptureCommand(capturer: ScreenCaptureKitCapturer())
            .run(options)

        print(outputs.listing)

        if let path = options.pngOutput, let png = outputs.png {
            try Data(png).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.reportOutput, let report = outputs.report {
            try write(report, to: path)
        }

    case .annotate(let options):
        let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: options.input)))
        let outputs = try AnnotateCommand(textProvider: VisionSemanticProvider())
            .run(imageBytes: bytes, options: options)

        print(
            zip(options.marks, outputs.targets)
                .map { "\($0.label): \($1.canonicalText)" }
                .joined(separator: "\n")
        )

        if let path = options.pngOutput, let png = outputs.png {
            try Data(png).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.svgOutput, let svg = outputs.svg { try write(svg, to: path) }
        if let path = options.reportOutput, let report = outputs.report {
            try write(report, to: path)
        }
        if let path = options.traceOutput, let trace = outputs.trace { try write(trace, to: path) }

    case .stitch(let options):
        let frames = try options.inputs.map {
            [UInt8](try Data(contentsOf: URL(fileURLWithPath: $0)))
        }
        let outputs = try StitchCommand().run(frames: frames, options: options)

        print(outputs.report)

        if let path = options.pngOutput, let png = outputs.png {
            try Data(png).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.reportOutput { try write(outputs.report, to: path) }

        if outputs.uncertainJoinCount > 0 {
            fail("\(outputs.uncertainJoinCount) join(s) did not match; the page may be wrong")
        }

    case .record(let options):
        try await runRecord(options)

    case .redact(let options):
        let bytes = [UInt8](try Data(contentsOf: URL(fileURLWithPath: options.input)))
        let outputs = try RedactCommand(textProvider: VisionSemanticProvider())
            .run(imageBytes: bytes, options: options)

        print(outputs.report)

        if let path = options.pngOutput, let png = outputs.png {
            try Data(png).write(to: URL(fileURLWithPath: path))
        }
        if let path = options.reportOutput { try write(outputs.report, to: path) }

        if outputs.failureCount > 0 {
            fail("\(outputs.failureCount) mask(s) did not take; this picture is not safe to send")
        }

    case .compare(let options):
        let directory = URL(fileURLWithPath: options.input)
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let scenes = try files.map { url in
            CorpusInput(
                name: url.deletingPathExtension().lastPathComponent,
                json: try String(contentsOf: url, encoding: .utf8)
            )
        }

        let outputs = try CompareCommand().run(scenes: scenes, options: options)

        if let path = options.pageOutput, let page = outputs.page { try write(page, to: path) }
        if let report = outputs.report {
            print(report)
            if let path = options.reportOutput { try write(report, to: path) }
        }

    case .camera(let options):
        let json = try String(contentsOfFile: options.input, encoding: .utf8)
        let outputs = try CameraCommand().run(inputJSON: json, options: options)

        print(outputs.keyframes)

        if let path = options.keyframesOutput { try write(outputs.keyframes, to: path) }
        if let path = options.reportOutput, let report = outputs.report {
            try write(report, to: path)
        }

    case .renderVideo(let options):
        try await runRenderVideo(options)

    case .synthesise(let options):
        let json = try String(contentsOf: URL(fileURLWithPath: options.input), encoding: .utf8)
        let outputs = try SynthesiseCommand().run(sceneJSON: json)

        print(outputs.report)
        print(
            "replaced \(outputs.replacedLabels) labels and "
                + "\(outputs.replacedPictures) pictures")

        if let path = options.output { try write(outputs.scene, to: path) }
        if let path = options.reportOutput { try write(outputs.report, to: path) }

        if let input = options.traceInput, let path = options.traceOutput {
            let trace = try String(contentsOfFile: input, encoding: .utf8)
            try write(SynthesiseCommand().synthesised(trace: trace), to: path)
        }

    case .replay(let options):
        let bundleJSON = try String(contentsOfFile: options.input, encoding: .utf8)
        let outputs = try ReplayCommand().run(bundleJSON: bundleJSON, rerecord: options.rerecord)

        print(outputs.verdict.report)

        if let path = options.answerOutput { try write(outputs.answerText, to: path) }
        if let rerecorded = outputs.rerecorded { try write(rerecorded, to: options.input) }
        if !outputs.verdict.isUnchanged { exit(1) }

    case .bisect(let options):
        let bundleJSON = try String(contentsOfFile: options.input, encoding: .utf8)
        let search = try BisectCommand().run(bundleJSON: bundleJSON, options: options) { version in
            let line = BisectCommand.commandLine(
                options.run, version: version, bundle: options.input)
            print("asking \(version)")
            return try shell(line)
        }

        print(search.report)
    }
} catch {
    fail("\(error)")
}
