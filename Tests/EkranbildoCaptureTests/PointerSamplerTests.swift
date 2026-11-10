@testable import EkranbildoCapture
import EkranbildoContracts
import EkranbildoTestKit
import Testing

@Suite("Pointer sampler")
struct PointerSamplerTests {

    private func sampler(heartbeat: Double = 0.25) -> PointerSampler {
        PointerSampler(heartbeat: .seconds(heartbeat))
    }

    private func reading(x: Double, y: Double, pressed: Bool = false) -> PointerReading {
        PointerReading(position: ScreenPoint(x: x, y: y), pressed: pressed)
    }

    @Test("The first look is always written down")
    func firstIsAlwaysTaken() {
        var sampler = sampler()
        #expect(sampler.sample(reading(x: 10, y: 20), at: .zero) != nil)
    }

    @Test("A pointer that moved is written down")
    func movementIsTaken() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20), at: .zero)
        #expect(sampler.sample(reading(x: 11, y: 20), at: .seconds(0.01)) != nil)
    }

    @Test("A press is written down the moment it happens")
    func pressIsTaken() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20), at: .zero)
        #expect(sampler.sample(reading(x: 10, y: 20, pressed: true), at: .seconds(0.01)) != nil)
    }

    @Test("Letting go is written down too")
    func releaseIsTaken() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20, pressed: true), at: .zero)
        #expect(sampler.sample(reading(x: 10, y: 20), at: .seconds(0.01)) != nil)
    }

    @Test("A pointer that has not moved is not written down again straight away")
    func stillnessIsSkipped() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20), at: .zero)
        #expect(sampler.sample(reading(x: 10, y: 20), at: .seconds(0.01)) == nil)
    }

    @Test("A pointer that has not moved for a while is written down anyway")
    func stillnessIsStillRecorded() {
        var sampler = sampler(heartbeat: 0.25)
        _ = sampler.sample(reading(x: 10, y: 20), at: .zero)
        #expect(sampler.sample(reading(x: 10, y: 20), at: .seconds(0.1)) == nil)
        #expect(sampler.sample(reading(x: 10, y: 20), at: .seconds(0.25)) != nil)
    }

    @Test("The sample says where the pointer was and whether it was down")
    func saysWhatItSaw() throws {
        var sampler = sampler()
        let taken = sampler.sample(reading(x: 10, y: 20, pressed: true), at: .seconds(3))
        let sample = try #require(taken)
        #expect(sample.position == ScreenPoint(x: 10, y: 20))
        #expect(sample.pressed)
        #expect(sample.at == .seconds(3))
    }

    @Test("A moment that has already passed is not written down")
    func backwardsIsSkipped() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20), at: .seconds(5))
        #expect(sampler.sample(reading(x: 90, y: 90), at: .seconds(4)) == nil)
    }

    @Test("The same moment twice is written down once")
    func sameMomentIsSkipped() {
        var sampler = sampler()
        _ = sampler.sample(reading(x: 10, y: 20), at: .seconds(5))
        #expect(sampler.sample(reading(x: 90, y: 90), at: .seconds(5)) == nil)
        #expect(sampler.sample(reading(x: 90, y: 90, pressed: true), at: .seconds(5)) == nil)
    }

    @Test("Nothing seen is nothing written down")
    func nothingSeen() {
        var sampler = sampler()
        #expect(sampler.sample(nil, at: .zero) == nil)
    }

    @Test("The same looks give the same samples")
    func reproducible() {
        let looks: [(PointerReading?, Timestamp)] = [
            (reading(x: 10, y: 20), .zero),
            (reading(x: 10, y: 20), .seconds(0.05)),
            (reading(x: 12, y: 22, pressed: true), .seconds(0.1)),
            (nil, .seconds(0.15)),
            (reading(x: 12, y: 22), .seconds(0.5)),
        ]
        #expect(
            isReproducible {
                var sampler = PointerSampler(heartbeat: .seconds(0.25))
                return looks.compactMap { sampler.sample($0.0, at: $0.1) }
            })
    }
}
