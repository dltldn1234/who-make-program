import Testing
@testable import AgentLink

@Suite("Agent link QR pairing payload")
struct AgentLinkPairingPayloadTests {
    @Test("A six-digit pairing code round-trips through the QR payload")
    func roundTrip() throws {
        let payload = try #require(AgentLinkPairingPayload.encode(code: "381204"))
        #expect(AgentLinkPairingPayload.decode(payload) == "381204")
    }

    @Test("Foreign and malformed QR values are rejected")
    func rejectsMalformedPayloads() {
        #expect(AgentLinkPairingPayload.decode("https://example.com/?code=381204") == nil)
        #expect(AgentLinkPairingPayload.decode("agent-link://pair?code=12AB56") == nil)
        #expect(AgentLinkPairingPayload.encode(code: "12345") == nil)
    }
}
