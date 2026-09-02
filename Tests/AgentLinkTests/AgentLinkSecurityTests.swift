import Foundation
import Testing
@testable import AgentLink

@Suite("Agent link security")
struct AgentLinkSecurityTests {
    @Test("The same pairing code derives the same 256-bit secret")
    func deterministicPairingKey() throws {
        let first = try AgentLinkPairingKey.derive(from: "381204")
        let second = try AgentLinkPairingKey.derive(from: "381204")

        #expect(first == second)
        #expect(first.count == 32)
    }

    @Test("Different pairing codes derive different secrets")
    func distinctPairingKeys() throws {
        #expect(
            try AgentLinkPairingKey.derive(from: "381204") !=
            AgentLinkPairingKey.derive(from: "381205")
        )
    }

    @Test("Generated trust credentials contain 256 bits of entropy")
    func generatedCredential() throws {
        let peer = AgentDeviceIdentity(id: UUID(), name: "Test iPhone", kind: .iPhone)
        let credential = try AgentLinkCredential.generate(for: peer)

        #expect(credential.peer == peer)
        #expect(credential.secret.count == 32)
    }
}
