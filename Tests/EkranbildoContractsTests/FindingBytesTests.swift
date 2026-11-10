import EkranbildoContracts
import Testing

@Suite("Finding one run of bytes inside another")
struct FindingBytesTests {

    private let haystack: [UInt8] = Array("a PDF has /CreationDate (D:2026) in it".utf8)

    @Test("A run that is there is found")
    func found() {
        #expect(haystack.contains(Array("/CreationDate (".utf8)))
    }

    @Test("A run that is not there is not found")
    func absent() {
        #expect(!haystack.contains(Array("/Producer".utf8)))
    }

    @Test("Where it starts is where it starts")
    func position() {
        #expect(haystack.firstIndex(of: Array("/CreationDate".utf8)) == 10)
    }

    @Test("Nothing is everywhere, so it is at the beginning")
    func empty() {
        #expect(haystack.contains([]))
        #expect(haystack.firstIndex(of: []) == 0)
    }

    @Test("A run longer than what it is looked for in is not there")
    func tooLong() {
        #expect(![UInt8]([1, 2]).contains([1, 2, 3]))
    }

    @Test("Bytes that are not text at all can still be searched")
    func notText() {
        let binary: [UInt8] = [0x89, 0x50, 0xFF, 0xFE, 0x25, 0x50, 0x44, 0x46]
        #expect(binary.contains([0x25, 0x50, 0x44, 0x46]))
        #expect(!binary.contains([0x25, 0x50, 0x44, 0x47]))
    }

    @Test("A run at the very end is found")
    func atTheEnd() {
        #expect(haystack.contains(Array("in it".utf8)))
    }
}
