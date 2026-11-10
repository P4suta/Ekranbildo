import EkranbildoContracts
import EkranbildoCore
import EkranbildoFixtures
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoInspector
import EkranbildoLayout
import EkranbildoObservability
import EkranbildoRender
import EkranbildoRenderCoreGraphics
import EkranbildoSemantics
import Foundation

public struct AnnotateOptions: Sendable, Equatable {
    public let input: String
    public let marks: [Mark]
    public let pngOutput: String?
    public let svgOutput: String?
    public let reportOutput: String?
    public let traceOutput: String?
    public let captureScale: Double
    public let readsText: Bool
    public let padding: Double?
    public let numbered: Bool
    public let reading: ReadingDirection

    public struct Mark: Sendable, Equatable {
        public let point: ScenePoint
        public let label: String
    }

    public init(arguments: [String]) throws {
        let parsed = try FlagScanner.scan(arguments, knownFlags: Self.knownFlags)

        guard let input = parsed.positional.first else {
            throw CommandError(code: CommandError.missingInput, detail: "a screenshot is required")
        }
        guard parsed.positional.count == 1 else {
            throw CommandError(
                code: CommandError.unknownFlag,
                detail: "unexpected argument '\(parsed.positional[1])'"
            )
        }
        self.input = input

        marks = try parsed.values(of: "--point").map(Self.mark(from:))
        guard !marks.isEmpty else {
            throw CommandError(
                code: CommandError.missingValue,
                detail: "at least one --point <x,y:label> is required"
            )
        }

        pngOutput = parsed.value(of: "--png")
        svgOutput = parsed.value(of: "--svg")
        reportOutput = parsed.value(of: "--report")
        traceOutput = parsed.value(of: "--trace")
        readsText = parsed.value(of: "--text") != "no"

        numbered = parsed.value(of: "--steps") == "yes"

        if let name = parsed.value(of: "--reading") {
            guard let chosen = ReadingDirection(rawValue: name) else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: """
                        --reading must be one of \
                        \(ReadingDirection.allCases.map(\.rawValue).joined(separator: ", ")), \
                        got '\(name)'
                        """
                )
            }
            reading = chosen
        } else {
            reading = .leftToRight
        }

        if let text = parsed.value(of: "--beautify") {
            guard let value = Double(text), value >= 0, value.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--beautify needs points of padding, got '\(text)'"
                )
            }
            padding = value
        } else {
            padding = nil
        }

        if let text = parsed.value(of: "--capture-scale") {
            guard let value = Double(text), value > 0, value.isFinite else {
                throw CommandError(
                    code: CommandError.invalidValue,
                    detail: "--capture-scale needs a positive number, got '\(text)'"
                )
            }
            captureScale = value
        } else {
            captureScale = Defaults.captureScale
        }
    }

    static let knownFlags = [
        "--point", "--png", "--svg", "--report", "--trace", "--capture-scale", "--text",
        "--beautify", "--steps", "--reading",
    ]

    static func mark(from text: String) throws -> Mark {
        let parts = text.split(separator: Syntax.labelSeparator, maxSplits: 1)
        guard parts.count == Syntax.pointAndLabel else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--point needs x,y:label, got '\(text)'"
            )
        }
        let coordinates = parts[0].split(separator: Syntax.coordinateSeparator)
        guard coordinates.count == Syntax.coordinates,
            let x = Double(coordinates[0]), let y = Double(coordinates[1]),
            x.isFinite, y.isFinite, !parts[1].isEmpty
        else {
            throw CommandError(
                code: CommandError.invalidValue,
                detail: "--point needs x,y:label, got '\(text)'"
            )
        }
        return Mark(point: ScenePoint(x: x, y: y), label: String(parts[1]))
    }

    private enum Syntax {
        static let labelSeparator: Character = ":"
        static let coordinateSeparator: Character = ","
        static let pointAndLabel = 2
        static let coordinates = 2
    }

    public enum Defaults {
        public static let captureScale: Double = 1
    }
}

public struct AnnotateOutputs: Sendable, Equatable {
    public let png: [UInt8]?
    public let svg: String?
    public let report: String?
    public let trace: String?
    public let targets: [SceneRect]
}

public struct AnnotateCommand: Sendable {
    private let measurer: any TextMeasuring
    private let provider: (any SemanticProvider)?

    public init(
        measurer: any TextMeasuring = TabulatedTextMeasurer.uniform(),
        textProvider: (any SemanticProvider)? = nil
    ) {
        self.measurer = measurer
        provider = textProvider
    }

    public func run(imageBytes: [UInt8], options: AnnotateOptions) throws -> AnnotateOutputs {
        var trace = TraceLog(ticks: ManualTickSource())
        trace.beginSpan("annotate", attributes: [.of("marks", .int(Int64(options.marks.count)))])

        let decoded = try ImageCodec.decode(imageBytes)
        let image = decoded.image
        trace.event(
            "decoded",
            attributes: [
                .of("width", .int(Int64(image.width))),
                .of("height", .int(Int64(image.height))),
                .of("sourceColorSpace", .string(decoded.sourceColorSpace)),
            ]
        )

        let scale = options.captureScale
        let canvas = SceneRect(
            x: 0,
            y: 0,
            width: Double(image.width) / scale,
            height: Double(image.height) / scale
        )

        trace.beginSpan("detect")
        let detectors: [any SemanticProvider] =
            options.readsText
            ? [RegionSemanticProvider()] + (provider.map { [$0] } ?? [])
            : [RegionSemanticProvider()]
        let semantics = try CombinedSemanticProvider(detectors).analyse(image)
        let elements = semantics.elements.map { Self.inPoints($0, scale: scale) }
        trace.event(
            "detected",
            attributes: [
                .of("elements", .int(Int64(elements.count))),
                .of("provider", .string(semantics.providerVersion)),
            ]
        )
        trace.endSpan()

        let snapper = TargetSnapper()
        var annotations: [Annotation] = []
        var targets: [SceneRect] = []
        for (index, mark) in options.marks.enumerated() {
            let target =
                snapper.targets(among: elements, at: mark.point).first
                ?? SceneRect(
                    x: mark.point.x, y: mark.point.y, width: 0, height: 0
                ).raw.inset(by: -Defaults.bareClickRadius).asScene
            targets.append(target)
            annotations.append(
                Annotation(
                    id: AnnotationID(UInt32(index + 1)),
                    target: target,
                    label: mark.label,
                    placement: nil,
                    badge: options.numbered ? BadgeNumber(index + 1) : nil
                )
            )
            trace.event(
                "snapped",
                attributes: [
                    .of("label", .borrowed(mark.label)),
                    .of("target", .string(target.canonicalText)),
                ]
            )
        }

        trace.beginSpan("solve")
        let problem = LayoutProblem(
            canvas: canvas,
            style: .standard,
            annotations: annotations,
            measurer: measurer,
            elements: elements,
            saliency: semantics.saliency,
            reading: options.reading
        )
        let solution = ExactSolver().solve(problem, budget: .standard)
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
                .of("nodes", .int(Int64(solution.work.searchNodes))),
            ]
        )
        trace.endSpan()

        var store = InMemoryAssetStore()
        let background = store.store(image)
        let scene = Scene(
            canvas: canvas,
            background: background,
            annotations: solution.applied(to: annotations),
            style: .standard
        )
        let drawList =
            options.padding.map { padding in
                Beautifier(style: BeautifyStyle(padding: padding))
                    .drawList(for: scene, measurer: measurer)
            } ?? DrawListBuilder(measurer: measurer, reading: options.reading).build(scene)

        var png: [UInt8]?
        if options.pngOutput != nil {
            let result = try CoreGraphicsRenderer(assets: store).render(drawList, scale: scale)
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
        }

        trace.endSpan()
        trace.finish()

        return AnnotateOutputs(
            png: png,
            svg: options.svgOutput == nil ? nil : SVGRenderer().render(drawList),
            report: options.reportOutput == nil
                ? nil
                : InspectorReport(measurer: measurer).html(for: problem, solution: solution),
            trace: options.traceOutput == nil ? nil : trace.canonicalText,
            targets: targets
        )
    }

    static func inPoints(_ element: ScreenElement, scale: Double) -> ScreenElement {
        guard scale != 1 else { return element }
        return ScreenElement(
            rect: SceneRect(
                x: element.rect.minX / scale,
                y: element.rect.minY / scale,
                width: element.rect.raw.width / scale,
                height: element.rect.raw.height / scale
            ),
            kind: element.kind,
            text: element.text,
            confidence: element.confidence,
            provenance: element.provenance
        )
    }

    private enum Defaults {
        static let bareClickRadius: Double = 8
    }
}

extension Rect {
    fileprivate var asScene: SceneRect {
        SceneRect(x: minX, y: minY, width: width, height: height)
    }
}
