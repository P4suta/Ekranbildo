@testable import EkranbildoGeometry
import Testing

@Suite("DeterministicSum")
struct DeterministicSumTests {

    @Test("An empty sum is zero")
    func emptySumIsZero() {
        #expect(DeterministicSum().value() == 0)
        #expect(DeterministicSum.pairwiseReduce([]) == 0)
    }

    @Test("A single value is returned unchanged")
    func singleValue() {
        #expect(DeterministicSum([3.5]).value() == 3.5)
    }

    @Test("Small sums agree with naive addition", arguments: [1, 2, 3, 4, 5, 8, 17, 64, 1000])
    func agreesWithNaiveSumForWellConditionedInput(_ count: Int) {
        let values = (0..<count).map { Double($0) * 0.25 }
        let naive = values.reduce(0, +)
        #expect(approximatelyEqual(DeterministicSum(values).value(), naive, tolerance: 1e-9))
    }

    @Test("Pairwise folding beats a running sum on an ill-conditioned input")
    func pairwiseIsMoreAccurateThanRunningSum() {
        var values = [1e16]
        values.append(contentsOf: Array(repeating: 1.0, count: 10_000))
        let exact = 1e16 + 10_000.0

        let running = values.reduce(0, +)
        let pairwise = DeterministicSum(values).value()

        let runningError = abs(running - exact)
        let pairwiseError = abs(pairwise - exact)
        #expect(pairwiseError < runningError)
    }

    @Test("The same values in the same order give bit-identical results")
    func repeatedFoldsAreBitIdentical() {
        var generator = SplitMix64(seed: 20_260_913)
        let values = (0..<500).map { _ in
            Double(generator.next() % 1_000_000) / 7.0
        }

        let first = DeterministicSum(values).value()
        let second = DeterministicSum(values).value()
        #expect(first.bitPattern == second.bitPattern)
    }

    @Test("Folding is sensitive to input order, which is why the order is fixed by the caller")
    func orderIsPartOfTheContract() {
        let ascending = [1e16, 1.0, -1e16]
        let reordered = [1e16, -1e16, 1.0]
        #expect(DeterministicSum(ascending).value() != DeterministicSum(reordered).value())
    }

    @Test("Incremental addition matches bulk construction")
    func incrementalMatchesBulk() {
        let values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
        var incremental = DeterministicSum()
        for value in values {
            incremental.add(value)
        }
        #expect(incremental.value().bitPattern == DeterministicSum(values).value().bitPattern)
        #expect(incremental.count == values.count)
    }
}

@Suite("Approximate comparison")
struct ApproximateComparisonTests {

    @Test("Exactly equal values are equal even when infinite")
    func exactEqualityIncludingInfinity() {
        #expect(approximatelyEqual(1.0, 1.0))
        #expect(approximatelyEqual(.infinity, .infinity))
        #expect(!approximatelyEqual(.infinity, -.infinity))
    }

    @Test("Values within the tolerance compare equal, values outside do not")
    func toleranceBoundary() {
        #expect(approximatelyEqual(1.0, 1.0 + 1e-10, tolerance: 1e-9))
        #expect(!approximatelyEqual(1.0, 1.0 + 1e-8, tolerance: 1e-9))
    }

    @Test("Approximate comparison is symmetric in tolerance")
    func toleranceIsSymmetric() {
        #expect(approximatelyEqual(5.0, 4.0, tolerance: 1.0))
        #expect(approximatelyEqual(4.0, 5.0, tolerance: 1.0))
    }

    @Test("Three-way comparison reports ties explicitly")
    func threeWayComparison() {
        #expect(approximateCompare(1.0, 2.0, tolerance: 0.1) == .ascending)
        #expect(approximateCompare(2.0, 1.0, tolerance: 0.1) == .descending)
        #expect(approximateCompare(1.0, 1.05, tolerance: 0.1) == .tie)
        #expect(approximateCompare(1.0, 1.0, tolerance: 0.0) == .tie)
    }

    @Test("Three-way comparison is antisymmetric")
    func threeWayComparisonIsAntisymmetric() {
        var generator = SplitMix64(seed: 7)
        for _ in 0..<200 {
            let a = Double(generator.next() % 1000) / 10.0
            let b = Double(generator.next() % 1000) / 10.0
            let forward = approximateCompare(a, b, tolerance: 0.5)
            let backward = approximateCompare(b, a, tolerance: 0.5)
            switch forward {
            case .ascending: #expect(backward == .descending)
            case .descending: #expect(backward == .ascending)
            case .tie: #expect(backward == .tie)
            }
        }
    }
}

@Suite("Stable identifiers")
struct StableIDTests {
    private enum TestTag {}
    private typealias TestID = StableID<TestTag>

    @Test("Identifiers order by raw value")
    func ordering() {
        #expect(TestID(1) < TestID(2))
        #expect(!(TestID(2) < TestID(1)))
        let constructedOnce = TestID(3)
        let constructedAgain = TestID(3)
        #expect(constructedOnce == constructedAgain)
    }

    @Test("The allocator hands out a monotonically increasing sequence")
    func allocatorIsMonotonic() {
        var allocator = IDAllocator<TestTag>()
        let allocated = (0..<5).map { _ in allocator.allocate() }
        #expect(allocated.map(\.raw) == [1, 2, 3, 4, 5])
        #expect(allocator.peek == 6)
    }

    @Test("Two allocators started at the same point produce the same identifiers")
    func allocatorIsReproducible() {
        var first = IDAllocator<TestTag>(startingAt: 100)
        var second = IDAllocator<TestTag>(startingAt: 100)
        for _ in 0..<10 {
            #expect(first.allocate() == second.allocate())
        }
    }
}

@Suite("SplitMix64")
struct SplitMix64Tests {

    @Test("Seed zero produces the reference sequence")
    func referenceSequenceForSeedZero() {
        var generator = SplitMix64(seed: 0)
        #expect(generator.next() == 0xE220_A839_7B1D_CDAF)
        #expect(generator.next() == 0x6E78_9E6A_A1B9_65F4)
        #expect(generator.next() == 0x06C4_5D18_8009_454F)
        #expect(generator.next() == 0xF88B_B8A8_724C_81EC)
    }

    @Test("Seed forty-two produces the reference sequence")
    func referenceSequenceForSeed42() {
        var generator = SplitMix64(seed: 42)
        #expect(generator.next() == 0xBDD7_3226_2FEB_6E95)
        #expect(generator.next() == 0x28EF_E333_B266_F103)
        #expect(generator.next() == 0x4752_6757_130F_9F52)
        #expect(generator.next() == 0x581C_E1FF_0E4A_E394)
    }

    @Test("Equal seeds give equal sequences and different seeds diverge")
    func seedDeterminesTheSequence() {
        var a = SplitMix64(seed: 12345)
        var b = SplitMix64(seed: 12345)
        var c = SplitMix64(seed: 12346)

        let fromA = (0..<16).map { _ in a.next() }
        let fromB = (0..<16).map { _ in b.next() }
        let fromC = (0..<16).map { _ in c.next() }

        #expect(fromA == fromB)
        #expect(fromA != fromC)
    }
}
