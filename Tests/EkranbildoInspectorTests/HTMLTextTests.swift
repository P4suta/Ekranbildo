@testable import EkranbildoInspector
import Testing

@Suite("HTML text")
struct HTMLTextTests {

    @Test(
        "Every character with a meaning in markup is escaped",
        arguments: [
            ("<script>", "&lt;script&gt;"),
            ("a & b", "a &amp; b"),
            ("\"quoted\"", "&quot;quoted&quot;"),
            ("it's", "it&#39;s"),
            ("<a href=\"x\">", "&lt;a href=&quot;x&quot;&gt;"),
        ]
    )
    func escapes(input: String, expected: String) {
        #expect(HTMLText.escaped(input) == expected)
    }

    @Test("Ordinary text is left alone")
    func passesThrough() {
        #expect(HTMLText.escaped("Save changes") == "Save changes")
        #expect(HTMLText.escaped("設定を開く") == "設定を開く")
        #expect(HTMLText.escaped("").isEmpty)
    }

    @Test("An already-escaped string is recognisably wrong rather than silently fine")
    func doubleEscaping() {
        #expect(HTMLText.escaped("&amp;") == "&amp;amp;")
    }
}
