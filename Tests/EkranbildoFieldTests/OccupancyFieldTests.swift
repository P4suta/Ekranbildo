import EkranbildoContracts
@testable import EkranbildoField
import EkranbildoGeometry
import EkranbildoTestKit
import Testing

@Suite("OccupancyField")
struct OccupancyFieldTests {

    private func field(
        canvas: SceneRect = SceneRect(x: 0, y: 0, width: 64, height: 32),
        cellSize: Double = 8,
        obstacles: [(SceneRect, Double)] = []
    ) -> OccupancyField {
        var builder = OccupancyFieldBuilder(canvas: canvas, cellSize: cellSize)
        for (rect, weight) in obstacles {
            builder.add(rect, weight: weight, to: .elements)
        }
        return builder.build()
    }

    @Test("The grid covers the canvas, rounding up to whole cells")
    func gridSize() {
        #expect(field().columns == 8)
        #expect(field().rows == 4)
        let ragged = field(canvas: SceneRect(x: 0, y: 0, width: 65, height: 33))
        #expect(ragged.columns == 9)
        #expect(ragged.rows == 5)
    }

    @Test("An empty field costs nothing anywhere")
    func emptyField() {
        let empty = field()
        #expect(empty.meanCost(in: SceneRect(x: 0, y: 0, width: 64, height: 32)) == 0)
        #expect(empty.meanCost(in: SceneRect(x: 10, y: 10, width: 5, height: 5)) == 0)
    }

    @Test("An obstacle raises the cost of the cells it covers")
    func obstacleCost() {
        let occupied = field(obstacles: [(SceneRect(x: 0, y: 0, width: 8, height: 8), 1)])
        #expect(occupied.meanCost(in: SceneRect(x: 0, y: 0, width: 8, height: 8)) == 1)
        #expect(occupied.meanCost(in: SceneRect(x: 32, y: 16, width: 8, height: 8)) == 0)
    }

    @Test("Mean cost over a region averages the cells it covers")
    func meanOverMixedRegion() {
        let occupied = field(obstacles: [(SceneRect(x: 0, y: 0, width: 8, height: 8), 1)])
        #expect(approximatelyEqual(occupied.meanCost(in: SceneRect(x: 0, y: 0, width: 16, height: 16)), 0.25))
    }

    @Test("Weights accumulate but saturate at one within a layer")
    func weightsSaturate() {
        let cell = SceneRect(x: 0, y: 0, width: 8, height: 8)
        let stacked = field(obstacles: [(cell, 0.7), (cell, 0.7)])
        #expect(stacked.meanCost(in: cell) == 1)
        #expect(stacked.meanCost(in: cell, layer: .elements) == 1)

        let single = field(obstacles: [(cell, 0.7)])
        #expect(approximatelyEqual(single.meanCost(in: cell, layer: .elements), 0.7))
    }

    @Test("A rectangle covering part of a cell contributes in proportion")
    func fractionalCoverage() {
        let half = field(obstacles: [(SceneRect(x: 0, y: 0, width: 4, height: 8), 1)])
        #expect(approximatelyEqual(half.meanCost(in: SceneRect(x: 0, y: 0, width: 8, height: 8)), 0.5))

        let quarter = field(obstacles: [(SceneRect(x: 0, y: 0, width: 4, height: 4), 1)])
        #expect(
            approximatelyEqual(quarter.meanCost(in: SceneRect(x: 0, y: 0, width: 8, height: 8)), 0.25)
        )
    }

    @Test("A region outside the canvas costs the out-of-bounds penalty")
    func outsideTheCanvas() {
        let empty = field()
        #expect(empty.meanCost(in: SceneRect(x: -40, y: -40, width: 8, height: 8)) == 1)
        #expect(empty.meanCost(in: SceneRect(x: 200, y: 200, width: 8, height: 8)) == 1)
    }

    @Test("A region straddling the edge mixes real cost with the penalty")
    func straddlingTheEdge() {
        let empty = field()
        let cost = empty.meanCost(in: SceneRect(x: -8, y: 0, width: 16, height: 8))
        #expect(cost > 0)
        #expect(cost < 1)
    }

    @Test("A degenerate region has no cost rather than dividing by zero")
    func degenerateRegion() {
        #expect(field().meanCost(in: SceneRect(x: 10, y: 10, width: 0, height: 0)) == 0)
    }

    @Test("Region queries agree with summing the cells directly")
    func matchesBruteForce() {
        var generator = SplitMix64(seed: 4_242)
        var builder = OccupancyFieldBuilder(
            canvas: SceneRect(x: 0, y: 0, width: 160, height: 96),
            cellSize: 8
        )
        for _ in 0..<12 {
            builder.add(
                SceneRect(
                    x: Double(generator.next() % 150),
                    y: Double(generator.next() % 90),
                    width: Double(generator.next() % 40) + 1,
                    height: Double(generator.next() % 30) + 1
                ),
                weight: Double(generator.next() % 100) / 100,
                to: .elements
            )
        }
        let built = builder.build()

        for _ in 0..<400 {
            let region = SceneRect(
                x: Double(generator.next() % 150),
                y: Double(generator.next() % 90),
                width: Double(generator.next() % 40) + 1,
                height: Double(generator.next() % 30) + 1
            )
            #expect(
                approximatelyEqual(
                    built.meanCost(in: region),
                    built.slowMeanCost(in: region),
                    tolerance: 1e-9
                ),
                "region \(region) disagreed"
            )
        }
    }

    @Test("Layers are kept separately as well as composited")
    func layersAreSeparate() {
        var builder = OccupancyFieldBuilder(
            canvas: SceneRect(x: 0, y: 0, width: 32, height: 32),
            cellSize: 8
        )
        builder.add(SceneRect(x: 0, y: 0, width: 8, height: 8), weight: 1, to: .elements)
        builder.add(SceneRect(x: 8, y: 0, width: 8, height: 8), weight: 1, to: .placedAnnotations)
        let built = builder.build()

        #expect(built.meanCost(in: SceneRect(x: 0, y: 0, width: 8, height: 8), layer: .elements) == 1)
        #expect(
            built.meanCost(in: SceneRect(x: 0, y: 0, width: 8, height: 8), layer: .placedAnnotations) == 0
        )
        #expect(built.meanCost(in: SceneRect(x: 8, y: 0, width: 8, height: 8)) == 1)
    }

    @Test("Building the same field twice gives identical cells")
    func reproducible() {
        let obstacles = [
            (SceneRect(x: 3, y: 5, width: 17, height: 9), 0.4),
            (SceneRect(x: 20, y: 1, width: 11, height: 23), 0.9),
        ]
        #expect(isReproducible { field(obstacles: obstacles).cells })
    }
}

@Suite("Corridor cost")
struct CorridorCostTests {

    private func field(obstacles: [SceneRect]) -> OccupancyField {
        var builder = OccupancyFieldBuilder(
            canvas: SceneRect(x: 0, y: 0, width: 128, height: 64),
            cellSize: 8
        )
        for rect in obstacles {
            builder.add(rect, weight: 1, to: .elements)
        }
        return builder.build()
    }

    @Test("A corridor through empty space costs nothing")
    func clearCorridor() {
        let empty = field(obstacles: [])
        let line = Polyline(points: [P2(x: 8, y: 32), P2(x: 120, y: 32)])
        #expect(empty.corridorCost(line, halfWidth: 4) == 0)
    }

    @Test("A corridor through an obstacle costs more than one beside it")
    func blockedCorridor() {
        let blocked = field(obstacles: [SceneRect(x: 56, y: 24, width: 16, height: 16)])
        let through = Polyline(points: [P2(x: 8, y: 32), P2(x: 120, y: 32)])
        let beside = Polyline(points: [P2(x: 8, y: 8), P2(x: 120, y: 8)])
        #expect(blocked.corridorCost(through, halfWidth: 4) > blocked.corridorCost(beside, halfWidth: 4))
    }

    @Test("The sample count does not depend on the length of the line")
    func fixedSampleCount() {
        let empty = field(obstacles: [])
        #expect(empty.corridorSampleCount == 32)
        let short = Polyline(points: [P2(x: 8, y: 8), P2(x: 12, y: 8)])
        let long = Polyline(points: [P2(x: 8, y: 8), P2(x: 120, y: 8)])
        #expect(empty.samplesTaken(for: short) == empty.samplesTaken(for: long))
    }

    @Test("Samples sit at step centres, not at the ends of the line")
    func samplesAreCentred() {
        let empty = field(obstacles: [])
        let line = Polyline(points: [P2(x: 0, y: 32), P2(x: 128, y: 32)])
        let points = empty.corridorSamplePoints(of: line)

        #expect(points.count == 32)
        let step = 128.0 / 32
        #expect(approximatelyEqual(points[0].x, step / 2, tolerance: 1e-9))
        #expect(approximatelyEqual(points[31].x, 128 - step / 2, tolerance: 1e-9))
        #expect(approximatelyEqual(points[1].x - points[0].x, step, tolerance: 1e-9))
    }

    @Test("Reversing a line mirrors its samples and keeps its cost")
    func reversalIsSymmetric() {
        let blocked = field(obstacles: [SceneRect(x: 0, y: 24, width: 20, height: 16)])
        let forwards = Polyline(points: [P2(x: 0, y: 32), P2(x: 128, y: 32)])
        let backwards = Polyline(points: [P2(x: 128, y: 32), P2(x: 0, y: 32)])

        let there = blocked.corridorSamplePoints(of: forwards).map(\.x)
        let back = blocked.corridorSamplePoints(of: backwards).map(\.x).reversed()
        for (a, b) in zip(there, back) {
            #expect(approximatelyEqual(a, b, tolerance: 1e-9))
        }
        #expect(
            approximatelyEqual(
                blocked.corridorCost(forwards, halfWidth: 4),
                blocked.corridorCost(backwards, halfWidth: 4),
                tolerance: 1e-12
            )
        )
    }

    @Test("A degenerate line has no corridor")
    func degenerateLine() {
        let empty = field(obstacles: [])
        #expect(empty.corridorCost(Polyline(points: []), halfWidth: 4) == 0)
        #expect(empty.corridorCost(Polyline(points: [P2(x: 1, y: 1)]), halfWidth: 4) == 0)
    }

    @Test("Corridor cost is the same each time it is computed")
    func reproducible() {
        let blocked = field(obstacles: [SceneRect(x: 40, y: 20, width: 24, height: 24)])
        let line = Polyline(points: [P2(x: 4, y: 4), P2(x: 100, y: 50), P2(x: 120, y: 10)])
        #expect(isReproducible { blocked.corridorCost(line, halfWidth: 5) })
    }
}
