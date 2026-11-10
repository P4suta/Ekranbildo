import EkranbildoContracts
import EkranbildoGeometry

public struct Synthesis: Sendable {
    private let salt: UInt64

    public init(salt: UInt64 = Defaults.salt) {
        self.salt = salt
    }

    public enum Defaults {
        public static let salt: UInt64 = 0x536E_6170_6C79_5379
    }

    public func synthesised(_ scene: Scene) -> Scene {
        scene.replacing(
            annotations: scene.annotations.map {
                $0.replacing(label: synthesised($0.label))
            },
            background: .some(scene.background.map(synthesised)),
            unknownKeys: .nothing
        )
    }

    public func synthesised(_ image: ImageRef) -> ImageRef {
        ImageRef(
            contentHash: Self.name(of: seed(for: image.contentHash)),
            pixelWidth: image.pixelWidth,
            pixelHeight: image.pixelHeight
        )
    }

    public func block(like image: ImageBuffer) -> ImageBuffer {
        var generator = SplitMix64(seed: salt)
        let shade = UInt8(truncatingIfNeeded: generator.next() >> Shade.spread)
        return ImageBuffer(
            width: image.width,
            height: image.height,
            colorSpace: image.colorSpace,
            pixels: (0..<(image.width * image.height * ImageBuffer.Channel.count)).map { index in
                index % ImageBuffer.Channel.count == ImageBuffer.Channel.Offset.alpha
                    ? UInt8(ImageBuffer.Channel.maximum) : shade
            }
        )
    }

    public func synthesised(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var generator = SplitMix64(seed: seed(for: text))
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            if character == " " {
                result.append(" ")
                continue
            }
            let alphabet = Alphabet.like(character)
            result.append(alphabet[Int(generator.next() % UInt64(alphabet.count))])
        }
        return result
    }

    private func seed(for text: String) -> UInt64 {
        var hash = Hash.offset
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= Hash.prime
        }
        return hash ^ salt
    }

    private static func name(of seed: UInt64) -> String {
        var generator = SplitMix64(seed: seed)
        var result = "synthetic-"
        for _ in 0..<Naming.digits {
            result.append(
                Alphabet.letters[Int(generator.next() % UInt64(Alphabet.letters.count))])
        }
        return result
    }

    private enum Alphabet {
        static let letters = Array("abcdefghijklmnopqrstuvwxyz")

        static let wide = Array("東西南北上下左右山川田口目手足月日火水木金土人大小中")

        static func like(_ character: Character) -> [Character] {
            guard let scalar = character.unicodeScalars.first?.value else { return letters }
            return Width.fullRanges.contains(where: { $0.contains(scalar) }) ? wide : letters
        }
    }

    private enum Width {
        static let fullRanges: [ClosedRange<UInt32>] = [
            0x3000...0x30FF,
            0x3400...0x4DBF,
            0x4E00...0x9FFF,
            0xAC00...0xD7AF,
            0xFF00...0xFF60,
        ]
    }

    private enum Naming {
        static let digits = 12
    }

    private enum Shade {
        static let spread: UInt64 = 56
    }

    private enum Hash {
        static let offset: UInt64 = 0xcbf2_9ce4_8422_2325
        static let prime: UInt64 = 0x0000_0100_0000_01B3
    }
}
