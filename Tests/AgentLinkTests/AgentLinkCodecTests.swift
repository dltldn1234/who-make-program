import Foundation
import Testing
@testable import AgentLink

@Suite("Agent link protocol")
struct AgentLinkCodecTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("A command round-trips through the versioned codec")
    func roundTrip() throws {
        let envelope = AgentLinkEnvelope(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            sentAt: now,
            message: .command(text: "상태 알려줘")
        )
        let codec = AgentLinkCodec()
        let decoded = try codec.decode(codec.encode(envelope), now: now)
        #expect(decoded == envelope)
    }

    @Test("Expired messages are rejected")
    func rejectsExpiredMessages() {
        let envelope = AgentLinkEnvelope(sentAt: now.addingTimeInterval(-31), message: .heartbeat)
        #expect(throws: AgentLinkValidationError.staleMessage) {
            try AgentLinkCodec().validate(envelope, now: now)
        }
    }

    @Test("Pairing codes must contain exactly six digits")
    func validatesPairingCode() {
        let device = AgentDeviceIdentity(id: UUID(), name: "iPhone", kind: .iPhone)
        let envelope = AgentLinkEnvelope(sentAt: now, message: .pairingRequest(device: device, code: "12AB"))
        #expect(throws: AgentLinkValidationError.invalidPairingCode) {
            try AgentLinkCodec().validate(envelope, now: now)
        }
    }
}
