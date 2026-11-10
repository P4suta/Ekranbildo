import EkranbildoObservability
import Testing

@Suite("A code written as a number")
struct DiagnosticCodeLiteralTests {

    @Test("A code can be written as the number it is")
    func writtenAsANumber() {
        let code: DiagnosticCode = 210
        #expect(code == DiagnosticCode(210))
        #expect(code.raw == 210)
    }

    @Test("Two codes written the same way are the same code")
    func equality() {
        let one: DiagnosticCode = 42
        let other: DiagnosticCode = 42
        #expect(one == other)
    }

    @Test("It still says what it is")
    func stillDescribes() {
        let code: DiagnosticCode = 200
        #expect(code.description == DiagnosticCode(200).description)
    }
}
