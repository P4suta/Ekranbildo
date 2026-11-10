import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoImaging
import EkranbildoInspector
import EkranbildoLayout
import EkranbildoObservability
import EkranbildoRender
import EkranbildoRenderCoreGraphics
import Foundation

public struct RenderOptions: Sendable, Equatable {
    public let input: String
    public let pngOutput: String?
    public let svgOutput: String?
    public let traceOutput: String?
    public let reportOutput: String?
    public let bundleOutput: String?
    public let scale: Double

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(code: CommandError.missingInput, detail: "a scene file is required")
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }

        self.input = input
        pngOutput = parsed.value(of: "--png")
        svgOutput = parsed.value(of: "--svg")
        traceOutput = parsed.value(of: "--trace")
        reportOutput = parsed.value(of: "--report")
        bundleOutput = parsed.value(of: "--bundle")

        if let text = parsed.value(of: "--scale") {
            guard let parsedScale = Double(text), parsedScale > 0, parsedScale.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--scale needs a positive number, got '\(text)'"
                )
            }
            scale = parsedScale
        } else {
            scale = 1
        }
    }

    static let knownFlags = ["--png", "--svg", "--trace", "--report", "--scale", "--bundle"]
}

public struct RenderOutputs: Sendable, Equatable {
    public let png: [UInt8]?
    public let svg: String?
    public let trace: String?
    public let report: String?
    public let bundle: String?
}

public struct RenderCommand: Sendable {
    private let measurer: any TextMeasuring
    private let signposts: any SignpostEmitting

    public init(
        measurer: any TextMeasuring = TabulatedTextMeasurer.uniform(),
        signposts: any SignpostEmitting = NoSignposts()
    ) {
        self.measurer = measurer
        self.signposts = signposts
    }

    private func solve(_ scene: Scene, trace: inout TraceLog<ManualTickSource>) -> SolvedScene {
        let unplaced = scene.annotations.filter { $0.placement == nil }
        guard !unplaced.isEmpty else { return SceneSolver(measurer: measurer).solve(scene) }

        trace.beginSpan("solve", attributes: [.of("annotations", .int(Int64(unplaced.count)))])
        let solved = SceneSolver(measurer: measurer).solve(scene)
        guard let solution = solved.solution else {
            trace.endSpan()
            return solved
        }

        for decision in solution.trace.decisions {
            trace.event(
                "placed",
                attributes: [
                    .of("annotation", .int(Int64(decision.annotationID.raw))),
                    .of("considered", .int(Int64(decision.consideredCount))),
                    .of("margin", .double(decision.margin)),
                ]
            )
        }
        for missing in solution.unplaced {
            trace.event(
                "unplaced",
                attributes: [
                    .of("annotation", .int(Int64(missing.annotationID.raw))),
                    .of("reason", .string(missing.reason)),
                ]
            )
        }
        trace.event(
            "solved",
            attributes: [
                .of("rung", .int(Int64(solution.relaxationRung))),
                .of("candidates", .int(Int64(solution.work.candidatesGenerated))),
                .of("nodes", .int(Int64(solution.work.searchNodes))),
                .of("pruned", .int(Int64(solution.work.prunedBranches))),
            ]
        )
        trace.endSpan()
        return solved
    }

    public func run(sceneJSON: String, options: RenderOptions) throws -> RenderOutputs {
        var trace = TraceLog(ticks: ManualTickSource(), signposts: signposts)

        trace.beginSpan("render", attributes: [.of("scale", .double(options.scale))])

        let pipeline = ReplayCommand.pipeline
        trace.event(
            "pipeline",
            attributes: [
                .of("candidates", .string(pipeline.candidateGeneration)),
                .of("normalization", .string(pipeline.normalization)),
                .of("weights", .string(pipeline.weights)),
                .of("comparator", .string(pipeline.comparator)),
                .of("renderer", .string(pipeline.renderer)),
                .of("vision", .string(pipeline.visionRevision)),
            ]
        )

        trace.beginSpan("decode")
        let scene: Scene
        do {
            scene = try JSONDecoder().decode(Scene.self, from: Data(sceneJSON.utf8))
        } catch {
            throw CommandError(
                code: CommandError.undecodableScene,
                detail: "could not decode the scene: \(error)"
            )
        }
        trace.event(
            "decoded",
            attributes: [
                .of("annotations", .int(Int64(scene.annotations.count))),
                .of("canvas", .string(scene.canvas.canonicalText)),
            ]
        )
        trace.endSpan()

        let solved = solve(scene, trace: &trace)
        let solvedScene = solved.scene

        trace.beginSpan("build")
        let drawList = DrawListBuilder(measurer: measurer).build(solvedScene)
        trace.event("built", attributes: [.of("commands", .int(Int64(drawList.commands.count)))])
        trace.endSpan()

        var svg: String?
        if options.svgOutput != nil {
            trace.beginSpan("svg")
            svg = SVGRenderer(imageHref: { "assets/\($0.contentHash).png" }).render(drawList)
            trace.endSpan()
        }

        var png: [UInt8]?
        if options.pngOutput != nil {
            trace.beginSpan("rasterise")
            let result = try CoreGraphicsRenderer().render(drawList, scale: options.scale)
            for warning in result.warnings {
                trace.event(
                    "warning",
                    attributes: [
                        .of("code", .string(warning.code.description)),
                        .of("detail", .borrowed(warning.detail)),
                    ]
                )
            }
            png = try result.bitmap.pngData()
            trace.event(
                "encoded",
                attributes: [
                    .of("width", .int(Int64(result.bitmap.width))),
                    .of("height", .int(Int64(result.bitmap.height))),
                    .of("bytes", .int(Int64(png?.count ?? 0))),
                ]
            )
            trace.endSpan()
        }

        var report: String?
        if options.reportOutput != nil, let problem = solved.problem,
            let solution = solved.solution
        {
            trace.beginSpan("report")
            report = InspectorReport(measurer: measurer).html(for: problem, solution: solution)
            trace.endSpan()
        }

        var bundle: String?
        if options.bundleOutput != nil {
            trace.beginSpan("bundle")
            bundle = try? ReplayBundle.encode(
                ReplayBundle(
                    scene: scene,
                    pipeline: ReplayCommand.pipeline,
                    answer: ReplayBundle.answer(for: solvedScene, reasons: solved.reasons)
                )
            )
            trace.endSpan()
        }

        trace.endSpan()
        trace.finish()

        return RenderOutputs(
            png: png,
            svg: svg,
            trace: options.traceOutput == nil ? nil : trace.canonicalText,
            report: report,
            bundle: bundle
        )
    }
}
