import CoreGraphics
import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoImaging
import EkranbildoObservability
import Foundation
import Vision

public struct VisionSemanticProvider: SemanticProvider {
    private let recognizesText: Bool
    private let findsSaliency: Bool

    public init(recognizesText: Bool = true, findsSaliency: Bool = true) {
        self.recognizesText = recognizesText
        self.findsSaliency = findsSaliency
    }

    public var version: String {
        "vision-text\(Revisions.text)-saliency\(Revisions.saliency)"
    }

    public enum Revisions {
        public static let text = VNRecognizeTextRequestRevision3
        public static let saliency = VNGenerateObjectnessBasedSaliencyImageRequestRevision2
    }

    public func analyse(_ image: ImageBuffer) throws -> SceneSemantics {
        try analyse(ImageCodec.cgImage(of: image))
    }

    public func analyse(_ image: CGImage) throws -> SceneSemantics {
        let canvas = SceneRect(
            x: 0, y: 0, width: Double(image.width), height: Double(image.height))
        let size = Size(width: canvas.raw.width, height: canvas.raw.height)

        var requests: [VNRequest] = []
        let text = VNRecognizeTextRequest()
        if recognizesText {
            text.revision = Revisions.text
            text.recognitionLevel = .accurate
            text.usesLanguageCorrection = false
            requests.append(text)
        }

        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        if findsSaliency {
            saliency.revision = Revisions.saliency
            requests.append(saliency)
        }

        if !requests.isEmpty {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform(requests)
            } catch {
                throw SemanticsError(
                    code: SemanticsError.recognitionFailed,
                    detail: "the recogniser could not read this picture: \(error)"
                )
            }
        }

        return SceneSemantics(
            canvas: canvas,
            elements: recognizesText ? Self.elements(from: text, size: size) : [],
            saliency: findsSaliency ? Self.saliency(from: saliency) : .empty,
            providerVersion: version
        )
    }

    static func elements(from request: VNRecognizeTextRequest, size: Size) -> [ScreenElement] {
        let observations = request.results ?? []
        return
            observations
            .compactMap { observation -> ScreenElement? in
                guard let candidate = observation.topCandidates(1).first,
                    !candidate.string.isEmpty
                else { return nil }
                let box = observation.boundingBox
                return ScreenElement(
                    rect: NormalizedBox(
                        x: box.origin.x,
                        y: box.origin.y,
                        width: box.size.width,
                        height: box.size.height
                    ).inScene(of: size),
                    kind: .text,
                    text: candidate.string,
                    confidence: Double(candidate.confidence),
                    provenance: .textRecognition
                )
            }
            .sorted {
                ($0.rect.minY, $0.rect.minX, $0.text ?? "")
                    < ($1.rect.minY, $1.rect.minX, $1.text ?? "")
            }
    }

    static func saliency(from request: VNGenerateObjectnessBasedSaliencyImageRequest) -> SaliencyMap {
        guard let observation = request.results?.first else { return .empty }
        let buffer = observation.pixelBuffer

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let columns = CVPixelBufferGetWidth(buffer)
        let rows = CVPixelBufferGetHeight(buffer)
        guard columns > 0, rows > 0, let base = CVPixelBufferGetBaseAddress(buffer) else {
            return .empty
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Double](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            let line = base.advanced(by: row * bytesPerRow).assumingMemoryBound(to: Float.self)
            for column in 0..<columns {
                values[row * columns + column] = min(1, max(0, Double(line[column])))
            }
        }
        return SaliencyMap(columns: columns, rows: rows, values: values)
    }
}
