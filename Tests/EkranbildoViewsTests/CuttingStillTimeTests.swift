import EkranbildoContracts
@testable import EkranbildoViews
import Testing

@Suite("Cutting the parts where nothing happened")
struct CuttingStillTimeTests {

    private static let rate = 30

    private func frame(_ shade: UInt8) -> ImageBuffer {
        ImageBuffer(
            width: 2,
            height: 2,
            colorSpace: .displayP3,
            pixels: [UInt8](repeating: shade, count: 2 * 2 * 4)
        )
    }

    private func frames(_ shades: [UInt8]) -> [ImageBuffer] {
        shades.map(frame)
    }

    private func kept(_ shades: [UInt8]) -> [UInt8] {
        RecordingPolish.withoutStillness(frames(shades), framesPerSecond: Self.rate)
            .map { $0.pixels[0] }
    }

    @Test("A long still run is shortened")
    func longStillRun() {
        let shades: [UInt8] = [1] + [UInt8](repeating: 2, count: 90) + [3]
        #expect(kept(shades).count < shades.count)
        #expect(kept(shades).first == 1)
        #expect(kept(shades).last == 3)
    }

    @Test("Something still is still there, briefly")
    func stillnessIsKept() {
        let shades: [UInt8] = [1] + [UInt8](repeating: 2, count: 90) + [3]
        #expect(kept(shades).contains(2))
    }

    @Test("A recording where everything changes is untouched")
    func nothingToCut() {
        let shades: [UInt8] = Array(1...60).map(UInt8.init)
        #expect(kept(shades) == shades)
    }

    @Test("It never makes a recording longer", arguments: [1, 5, 30, 120])
    func neverLonger(_ count: Int) {
        let shades = (0..<count).map { UInt8($0 % 3) }
        #expect(kept(shades).count <= shades.count)
    }

    @Test("What is left is in the order it was recorded in")
    func orderKept() {
        let shades: [UInt8] = [1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 4]
        let after = kept(shades)
        #expect(after.last == 4)
        #expect(after.firstIndex(of: 2) ?? 0 < after.firstIndex(of: 3) ?? 0)
    }

    @Test("A recording of one frame is that frame")
    func oneFrame() {
        #expect(kept([7]) == [7])
    }

    @Test("Nothing at all is nothing")
    func nothing() {
        #expect(kept([]).isEmpty)
    }

    @Test("The same recording is cut the same way twice")
    func reproducible() {
        let shades: [UInt8] = [1, 1, 1, 1, 1, 2, 2, 2, 2, 3]
        let once = kept(shades)
        let again = kept(shades)
        #expect(once == again)
    }
}
