import CoreGraphics
import EkranbildoContracts
@testable import EkranbildoRenderCoreGraphics
import Testing

@Suite("Drawing into somebody else's context")
struct DrawingIntoSomebodyElsesContextTests {

    private static let canvas = SceneRect(x: 0, y: 0, width: 40, height: 30)

    private static var list: DrawList {
        DrawList(
            canvas: canvas,
            colorSpace: .displayP3,
            commands: [
                .fill(
                    .rect(SceneRect(x: 0, y: 0, width: 20, height: 15)),
                    .solid(Color(red: 1, green: 1, blue: 1, alpha: 1))
                )
            ]
        )
    }

    private func context(backingScale: Int) throws -> CGContext {
        let width = Int(Self.canvas.width) * backingScale
        let height = Int(Self.canvas.height) * backingScale
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        )
        context.scaleBy(x: CGFloat(backingScale), y: CGFloat(backingScale))
        return context
    }

    private func inked(_ context: CGContext) -> Set<Point> {
        guard let data = context.data else { return [] }
        var found: Set<Point> = []
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        for y in 0..<context.height {
            for x in 0..<context.width {
                let alpha = bytes[y * context.bytesPerRow + x * 4]
                if alpha > 0 { found.insert(Point(x: x, y: y)) }
            }
        }
        return found
    }

    private struct Point: Hashable {
        let x: Int
        let y: Int
    }

    @Test("What is drawn lands inside a context that is one pixel per point")
    func oneToOne() throws {
        let context = try context(backingScale: 1)
        CoreGraphicsRenderer().draw(Self.list, into: context, scale: 1)
        #expect(!inked(context).isEmpty)
    }

    @Test(
        "What is drawn lands inside a context with a backing scale",
        arguments: [2, 3]
    )
    func retina(_ backingScale: Int) throws {
        let context = try context(backingScale: backingScale)
        CoreGraphicsRenderer().draw(Self.list, into: context, scale: 1)
        #expect(!inked(context).isEmpty)
    }

    @Test("What is drawn lands in the same place whatever the backing scale")
    func sameCorner() throws {
        var corners: [Point] = []
        for backingScale in [1, 2, 3] {
            let context = try context(backingScale: backingScale)
            CoreGraphicsRenderer().draw(Self.list, into: context, scale: 1)
            let ink = inked(context)
            let topLeft = try #require(
                ink.min { left, right in
                    (left.y, left.x) < (right.y, right.x)
                })
            corners.append(
                Point(x: topLeft.x / backingScale, y: topLeft.y / backingScale))
        }
        #expect(Set(corners).count == 1)
        #expect(corners.first == Point(x: 0, y: 0))
    }

    @Test("A tall canvas is not drawn above the top of the context")
    func tallCanvas() throws {
        let tall = SceneRect(x: 0, y: 0, width: 40, height: 400)
        let list = DrawList(
            canvas: tall,
            colorSpace: .displayP3,
            commands: [
                .fill(
                    .rect(SceneRect(x: 0, y: 0, width: 40, height: 400)),
                    .solid(Color(red: 1, green: 1, blue: 1, alpha: 1))
                )
            ]
        )
        let width = 40 * 2
        let height = 400 * 2
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
        )
        context.scaleBy(x: 2, y: 2)
        CoreGraphicsRenderer().draw(list, into: context, scale: 1)
        #expect(inked(context).count == width * height)
    }
}
