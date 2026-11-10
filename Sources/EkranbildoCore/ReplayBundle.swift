import EkranbildoContracts
import EkranbildoGeometry
import EkranbildoObservability
import Foundation

public struct RecordedPlacement: Hashable, Sendable, Codable {
    public let annotation: AnnotationID
    public let outcome: Outcome

    public init(annotation: AnnotationID, outcome: Outcome) {
        self.annotation = annotation
        self.outcome = outcome
    }

    public enum Outcome: Hashable, Sendable, Codable {
        case placed(Placement)
        case unplaced(reason: String)

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let placement = try container.decodeIfPresent(Placement.self, forKey: .placed) {
                self = .placed(placement)
                return
            }
            guard let reason = try container.decodeIfPresent(String.self, forKey: .unplaced) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "an outcome is either placed or unplaced, and this is "
                            + "neither"
                    )
                )
            }
            self = .unplaced(reason: reason)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .placed(let placement): try container.encode(placement, forKey: .placed)
            case .unplaced(let reason): try container.encode(reason, forKey: .unplaced)
            }
        }

        enum CodingKeys: String, CodingKey {
            case placed, unplaced
        }
    }

    public var summary: String {
        switch outcome {
        case .placed(let placement):
            "\(placement.direction) at \(CanonicalText.rounded(placement.leaderLength, places: 1))"
        case .unplaced(let reason):
            "not placed (\(reason))"
        }
    }
}

public struct AnswerChange: Hashable, Sendable {
    public let annotation: AnnotationID
    public let was: String
    public let now: String

    public init(annotation: AnnotationID, was: String, now: String) {
        self.annotation = annotation
        self.was = was
        self.now = now
    }
}

public enum ReplayVerdict: Hashable, Sendable {
    case matched
    case changed([AnswerChange])
    case incomparable(recorded: PipelineVersion, now: PipelineVersion)
}

extension ReplayVerdict {
    public var isUnchanged: Bool {
        switch self {
        case .matched: true
        case .changed, .incomparable: false
        }
    }

    public var report: String {
        switch self {
        case .matched:
            "unchanged: this build gives the recorded answer"
        case .changed(let changes):
            (["\(changes.count) placement(s) changed:"]
                + changes.map { "  annotation \($0.annotation.raw): \($0.was) -> \($0.now)" })
                .joined(separator: "\n")
        case .incomparable(let recorded, let now):
            """
            not comparable: the recording was made by a build that decides differently.

            recorded by: \(recorded.canonicalText)
               running:  \(now.canonicalText)

            Nothing here says anything is wrong. Replay this bundle on the build \
            that recorded it, or record a new one from this build.
            """
        }
    }
}

public struct ReplayBundleError: Error, Equatable {
    public let detail: String

    public init(detail: String) {
        self.detail = detail
    }
}

public struct ReplayBundle: Hashable, Sendable, Codable {
    public static let currentFormat = 1

    public let format: Int
    public let scene: Scene
    public let pipeline: PipelineVersion
    public let answer: [RecordedPlacement]

    public init(
        scene: Scene,
        pipeline: PipelineVersion,
        answer: [RecordedPlacement],
        format: Int = Self.currentFormat
    ) {
        self.format = format
        self.scene = scene
        self.pipeline = pipeline
        self.answer = answer
    }

    public func compare(_ now: [RecordedPlacement], from running: PipelineVersion) -> ReplayVerdict {
        guard pipeline == running else {
            return .incomparable(recorded: pipeline, now: running)
        }

        var changes: [AnswerChange] = []
        for placement in now {
            let recorded = answer.first { $0.annotation == placement.annotation }
            guard recorded?.outcome != placement.outcome else { continue }
            changes.append(
                AnswerChange(
                    annotation: placement.annotation,
                    was: recorded?.summary ?? Missing.fromTheRecording,
                    now: placement.summary
                )
            )
        }
        for recorded in answer where !now.contains(where: { $0.annotation == recorded.annotation }) {
            changes.append(
                AnswerChange(
                    annotation: recorded.annotation,
                    was: recorded.summary,
                    now: Missing.fromThisRun
                )
            )
        }

        guard !changes.isEmpty else { return .matched }
        return .changed(changes.sorted { $0.annotation.raw < $1.annotation.raw })
    }

    private enum Missing {
        static let fromTheRecording = "nothing recorded"
        static let fromThisRun = "nothing this time"
        static let unexplained = "no reason recorded"
    }

    public static func answer(
        for scene: Scene,
        reasons: [UnplacedReason] = []
    ) -> [RecordedPlacement] {
        scene.annotations.map { annotation in
            guard let placement = annotation.placement else {
                let reason = reasons.first { $0.annotation == annotation.id }?.reason
                return RecordedPlacement(
                    annotation: annotation.id,
                    outcome: .unplaced(reason: reason ?? Missing.unexplained)
                )
            }
            return RecordedPlacement(annotation: annotation.id, outcome: .placed(placement))
        }
    }

    public static func encode(_ bundle: Self) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let text = String(bytes: try encoder.encode(bundle), encoding: .utf8) else {
            throw ReplayBundleError(detail: "the bundle did not encode as text")
        }
        return text
    }

    public static func decode(_ text: String) throws -> Self {
        let bundle: Self
        do {
            bundle = try JSONDecoder().decode(Self.self, from: Data(text.utf8))
        } catch {
            throw ReplayBundleError(detail: "could not read the bundle: \(error)")
        }
        guard bundle.format <= currentFormat else {
            throw ReplayBundleError(
                detail: "the bundle is format \(bundle.format) and this build reads "
                    + "up to \(currentFormat); use a newer build to replay it"
            )
        }
        return bundle
    }
}
