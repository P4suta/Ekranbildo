import CoreGraphics
import CoreText
import EkranbildoContracts
import EkranbildoImaging
import EkranbildoObservability
import Foundation

extension CoreGraphicsRenderer {

    func draw(_ command: DrawCommand, in context: CGContext, warnings: inout [RenderWarning]) {
        switch command {
        case .fill(let path, let paint):
            guard let cgPath = Self.makePath(path) else { return }
            context.saveGState()
            context.addPath(cgPath)
            context.clip()
            fill(paint, in: context)
            context.restoreGState()

        case .stroke(let path, let stroke):
            guard let cgPath = Self.makePath(path) else { return }
            context.saveGState()
            context.setLineWidth(CGFloat(stroke.width))
            context.setLineCap(Self.lineCap(stroke.cap))
            context.setLineJoin(Self.lineJoin(stroke.join))
            context.setMiterLimit(CGFloat(stroke.miterLimit))
            if !stroke.dash.isEmpty {
                context.setLineDash(phase: 0, lengths: stroke.dash.map { CGFloat($0) })
            }
            if case .solid(let color) = stroke.paint {
                context.setStrokeColor(Self.cgColor(color, in: context))
                context.addPath(cgPath)
                context.strokePath()
            } else {
                context.addPath(cgPath)
                context.replacePathWithStrokedPath()
                context.clip()
                fill(stroke.paint, in: context)
            }
            context.restoreGState()

        case .text(let run):
            draw(run, in: context, warnings: &warnings)

        case .shadow(let path, let shadow):
            draw(shadow, under: path, in: context)

        case .image(let ref, let rect, let opacity, let cornerRadius):
            draw(
                Picture(ref: ref, rect: rect, opacity: opacity, cornerRadius: cornerRadius),
                in: context,
                warnings: &warnings
            )
        }
    }

    private func fill(_ paint: Paint, in context: CGContext) {
        switch paint {
        case .solid(let color):
            context.setFillColor(Self.cgColor(color, in: context))
            context.fill(context.boundingBoxOfClipPath)

        case .linearGradient(let stops, let start, let end):
            let colors =
                stops.map { Self.cgColor($0.color, in: context) } as CFArray
            let locations = stops.map { CGFloat($0.location) }
            guard
                let gradient = CGGradient(
                    colorsSpace: context.colorSpace, colors: colors, locations: locations)
            else { return }
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: start.x, y: start.y),
                end: CGPoint(x: end.x, y: end.y),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
    }

    private func draw(_ run: TextRun, in context: CGContext, warnings: inout [RenderWarning]) {
        guard !run.text.isEmpty else { return }

        let resolved = Self.resolveFont(run.font)
        if resolved.substituted {
            warnings.append(
                RenderWarning(
                    code: RenderWarning.fontSubstituted,
                    detail: """
                        font family '\(run.font.family)' is not installed; \
                        '\(resolved.family)' was used instead. Bundle the intended face with the \
                        app: a system face's metrics change between OS releases and will \
                        silently reflow every label.
                        """
                )
            )
        }

        guard case .solid(let color) = run.paint else { return }

        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.setFillColor(Self.cgColor(color, in: context))

        let attributes: [CFString: Any] = [
            kCTFontAttributeName: resolved.font,
            kCTForegroundColorAttributeName: Self.cgColor(color, in: context),
        ]
        let attributed = CFAttributedStringCreate(
            nil, run.text as CFString, attributes as CFDictionary)
        guard let attributed else {
            context.restoreGState()
            return
        }
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: run.baselineOrigin.x, y: run.baselineOrigin.y)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    static func resolveFont(_ spec: FontSpec) -> FontResolution {
        let wanted = CTFontCreateWithName(spec.family as CFString, CGFloat(spec.size), nil)
        let got = CTFontCopyFamilyName(wanted) as String
        guard got.caseInsensitiveCompare(spec.family) != .orderedSame else {
            return FontResolution(font: wanted, family: got, substituted: false)
        }

        let fallback = CTFontCreateWithName(
            Fonts.fallbackFamily as CFString, CGFloat(spec.size), nil)
        return FontResolution(
            font: fallback,
            family: CTFontCopyFamilyName(fallback) as String,
            substituted: true
        )
    }

    struct FontResolution {
        let font: CTFont
        let family: String
        let substituted: Bool
    }

    enum Fonts {
        static let fallbackFamily = "Helvetica"
    }
}

extension CoreGraphicsRenderer {
    static func deduplicated(_ warnings: [RenderWarning]) -> [RenderWarning] {
        var seen: [RenderWarning] = []
        for warning in warnings where !seen.contains(warning) {
            seen.append(warning)
        }
        return seen
    }
}
