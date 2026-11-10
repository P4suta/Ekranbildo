@testable import EkranbildoRedaction
import EkranbildoTestKit
import Testing

@Suite("Finding secrets")
struct SecretDetectionTests {

    private func found(_ text: String) -> [Secret.Kind] {
        SecretDetector().secrets(in: text).map(\.kind)
    }

    @Test(
        "An email address is found",
        arguments: [
            "someone@example.com",
            "first.last+tag@sub.example.co.uk",
            "Contact: alice@example.org for help",
        ]
    )
    func emails(text: String) {
        #expect(found(text).contains(.emailAddress))
    }

    @Test(
        "A key that looks like a key is found",
        arguments: [
            "sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc",
            "ghp_" + "16C7e42F292c6912E7710c838347Ae178B4a",
            "AKIA" + "IOSFODNN7EXAMPLE",
            "xoxb-" + "2345678901-2345678901-AbCdEfGhIjKlMnOpQrStUv",
        ]
    )
    func apiKeys(text: String) {
        #expect(found(text).contains(.apiKey), "missed: \(text)")
    }

    @Test("A long unfamiliar token is treated as a key")
    func unfamiliarToken() {
        #expect(found("token=" + "9f8Ae2Bc7D1e4F6a0B3c5D7e9F1a3B5c7D9e1F3a").contains(.apiKey))
    }

    @Test("A JSON web token is found")
    func jsonWebToken() {
        let token =
            "eyJhbGci" + "OiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(found(token).contains(.jsonWebToken))
    }

    @Test(
        "A card number is found however it is spaced",
        arguments: [
            "4242424242424242",
            "5555555555554444",
            "4242 4242 4242 4242",
            "4242-4242-4242-4242",
        ]
    )
    func cardNumbers(text: String) {
        #expect(found(text).contains(.paymentCard), "missed: \(text)")
    }

    @Test("Sixteen digits that are not a card are left alone")
    func notACardNumber() {
        #expect(!found("1234567812345678").contains(.paymentCard))
    }

    @Test("An address that looks like a network address is found")
    func ipAddresses() {
        #expect(found("Server at 192.168.1.42 is down").contains(.networkAddress))
        #expect(found("2001:0db8:85a3:0000:0000:8a2e:0370:7334").contains(.networkAddress))
    }

    @Test(
        "A version number is not a network address",
        arguments: ["Ekranbildo 1.2.3 build 4", "version 1.2.3.45678", "10.0.0.1234"]
    )
    func versionNumber(text: String) {
        #expect(!found(text).contains(.networkAddress), "redacted: \(text)")
    }

    @Test("Ordinary prose has nothing in it")
    func prose() {
        #expect(found("Deployment target and signing identity are configured here.").isEmpty)
    }

    @Test("An empty string has nothing in it")
    func empty() {
        #expect(found("").isEmpty)
    }

    @Test("Something that merely contains an at sign is not an address")
    func notAnEmail() {
        #expect(!found("see @channel for details").contains(.emailAddress))
        #expect(!found("user@").contains(.emailAddress))
    }

    @Test("A secret knows where in the line it is")
    func range() throws {
        let line = "Contact alice@example.org today"
        let secret = try #require(SecretDetector().secrets(in: line).first)
        #expect(line[secret.range] == "alice@example.org")
    }

    @Test("Several secrets in one line are all found")
    func several() {
        let text = "alice@example.org and bob@example.org from 10.0.0.1"
        #expect(found(text).filter { $0 == .emailAddress }.count == 2)
        #expect(found(text).contains(.networkAddress))
    }

    @Test("Secrets are reported in the order they appear")
    func ordered() {
        let found = SecretDetector().secrets(in: "10.0.0.1 then alice@example.org")
        #expect(found.map(\.kind) == [.networkAddress, .emailAddress])
    }

    @Test("Finding is reproducible")
    func reproducible() {
        let text = "key sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc for alice@example.org"
        #expect(isReproducible { SecretDetector().secrets(in: text) })
    }
}
