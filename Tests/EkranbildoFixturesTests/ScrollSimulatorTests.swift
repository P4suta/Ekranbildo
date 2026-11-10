import EkranbildoContracts
@testable import EkranbildoFixtures
import EkranbildoTestKit
import Testing

@Suite("Scroll simulator")
struct ScrollSimulatorTests {

    private func page(height: Int = 600) -> ImageBuffer {
        ScrollSimulator.page(width: 200, height: height)
    }

    @Test("A frame is a window onto the page")
    func framesAreWindows() {
        let content = page()
        let simulator = ScrollSimulator(page: content, viewportHeight: 100)
        let frames = simulator.frames(offsets: [0, 60, 120])

        #expect(frames.count == 3)
        for frame in frames {
            #expect(frame.image.width == content.width)
            #expect(frame.image.height == 100)
        }
        for y in 0..<100 {
            #expect(frames[0].image[x: 50, y: y] == content[x: 50, y: y])
        }
    }

    @Test("A frame taken at an offset shows the page from there")
    func offsetContent() {
        let content = page()
        let frames = ScrollSimulator(page: content, viewportHeight: 100)
            .frames(offsets: [60])
        for y in 0..<100 {
            #expect(frames[0].image[x: 50, y: y] == content[x: 50, y: y + 60])
        }
    }

    @Test("Scrolling past the end clamps rather than running off")
    func clampsAtTheEnd() {
        let content = page(height: 300)
        let frames = ScrollSimulator(page: content, viewportHeight: 100)
            .frames(offsets: [1000])
        #expect(frames[0].offset == 200)
        for y in 0..<100 {
            #expect(frames[0].image[x: 50, y: y] == content[x: 50, y: y + 200])
        }
    }

    @Test("A sticky header stays put while the page moves")
    func stickyHeader() {
        let simulator = ScrollSimulator(
            page: page(),
            viewportHeight: 100,
            stickyTop: 20
        )
        let frames = simulator.frames(offsets: [0, 60, 120])
        for frame in frames.dropFirst() {
            for y in 0..<20 {
                #expect(frame.image[x: 50, y: y] == frames[0].image[x: 50, y: y])
            }
        }
        #expect(frames[1].image[x: 50, y: 50] != frames[0].image[x: 50, y: 50])
    }

    @Test("A sticky footer stays put too")
    func stickyFooter() {
        let simulator = ScrollSimulator(page: page(), viewportHeight: 100, stickyBottom: 15)
        let frames = simulator.frames(offsets: [0, 60])
        for y in 85..<100 {
            #expect(frames[1].image[x: 50, y: y] == frames[0].image[x: 50, y: y])
        }
    }

    @Test("A restless region changes between frames without the page moving")
    func restlessRegion() {
        let simulator = ScrollSimulator(
            page: page(),
            viewportHeight: 100,
            restless: SceneRect(x: 160, y: 10, width: 30, height: 20)
        )
        let frames = simulator.frames(offsets: [0, 0])
        #expect(frames[0].image[x: 170, y: 20] != frames[1].image[x: 170, y: 20])
        #expect(frames[0].image[x: 50, y: 50] == frames[1].image[x: 50, y: 50])
    }

    @Test("Noise shifts pixels without moving the page")
    func noise() {
        let clean = ScrollSimulator(page: page(), viewportHeight: 100).frames(offsets: [0])
        let noisy = ScrollSimulator(page: page(), viewportHeight: 100, noise: 3)
            .frames(offsets: [0])
        #expect(clean[0].image.pixels != noisy[0].image.pixels)

        for (a, b) in zip(clean[0].image.pixels, noisy[0].image.pixels) {
            #expect(abs(Int(a) - Int(b)) <= 3)
        }
    }

    @Test("A simulation is reproducible")
    func reproducible() {
        let content = page()
        #expect(
            isReproducible {
                ScrollSimulator(page: content, viewportHeight: 100, noise: 4)
                    .frames(offsets: [0, 55, 110])
                    .map(\.image.pixels)
            }
        )
    }

    @Test("Noise depends on where it is as well as on the run")
    func noiseVaries() {
        let frames = ScrollSimulator(page: page(), viewportHeight: 100, noise: 5)
            .frames(offsets: [0])
        let clean = ScrollSimulator(page: page(), viewportHeight: 100).frames(offsets: [0])
        let differences = zip(frames[0].image.pixels, clean[0].image.pixels)
            .map { abs(Int($0) - Int($1)) }
        #expect(Set(differences).count > 1, "every pixel was shifted by the same amount")
    }
}
