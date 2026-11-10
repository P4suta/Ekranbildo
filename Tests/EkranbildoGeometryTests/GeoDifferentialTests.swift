@testable import EkranbildoGeometry
import Testing

@Suite("Geo interior differential")
struct GeoInteriorDifferentialTests {

    private func sampledInterior(_ segment: Segment, _ rect: Rect, samples: Int = 8_001) -> Bool {
        guard rect.width > 0, rect.height > 0 else { return false }
        let delta = segment.delta
        let margin = Tolerance.geometric
        for step in 0...samples {
            let t = Double(step) / Double(samples)
            let x = segment.a.x + delta.x * t
            let y = segment.a.y + delta.y * t
            if x > rect.minX + margin && x < rect.maxX - margin
                && y > rect.minY + margin && y < rect.maxY - margin
            {
                return true
            }
        }
        return false
    }

    @Test("Interior test agrees with dense sampling on random segments")
    func agreesWithSampling() {
        let rect = Rect(x: 10, y: 10, width: 20, height: 12)
        var generator = SplitMix64(seed: 0xC0FF_EE12_3456_789A)

        func coordinate() -> Double {
            Double(generator.next() % 500) / 10.0 - 5.0
        }

        struct Disagreement {
            let segment: Segment
            let actual: Bool
            let expected: Bool
        }

        var disagreements: [Disagreement] = []
        for _ in 0..<4_000 {
            let segment = Segment(
                a: P2(x: coordinate(), y: coordinate()),
                b: P2(x: coordinate(), y: coordinate())
            )
            let actual = Geo.segmentIntersectsInterior(segment, of: rect)
            let expected = sampledInterior(segment, rect)
            if actual != expected {
                disagreements.append(
                    Disagreement(segment: segment, actual: actual, expected: expected)
                )
            }
        }

        #expect(
            disagreements.isEmpty,
            "\(disagreements.count) disagreement(s), first: \(String(describing: disagreements.first))"
        )
    }

    @Test("Axis-aligned segments on and near the boundary agree with sampling")
    func agreesWithSamplingOnBoundaries() {
        let rect = Rect(x: 0, y: 0, width: 10, height: 10)
        let coordinates: [Double] = [-1, 0, 0.5, 5, 9.5, 10, 11]

        var disagreements = 0
        for ax in coordinates {
            for ay in coordinates {
                for bx in coordinates {
                    for by in coordinates {
                        let segment = Segment(a: P2(x: ax, y: ay), b: P2(x: bx, y: by))
                        if Geo.segmentIntersectsInterior(segment, of: rect)
                            != sampledInterior(segment, rect)
                        {
                            disagreements += 1
                        }
                    }
                }
            }
        }
        #expect(disagreements == 0, "\(disagreements) boundary case(s) disagreed with sampling")
    }
}
