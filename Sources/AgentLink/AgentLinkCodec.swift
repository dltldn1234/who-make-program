import Foundation

public enum AgentLinkValidationError: Error, Equatable, Sendable {
    case unsupportedProtocol(Int)
    case staleMessage
    case oversizedPayload
    case invalidPairingCode
    case invalidCommand
}

public struct AgentLinkCodec: Sendable {
    public static let maximumPayloadBytes = 16_384
    public static let maximumMessageAge: TimeInterval = 30

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    public func encode(_ envelope: AgentLinkEnvelope) throws -> Data {
        try validate(envelope, now: envelope.sentAt)
        let data = try encoder.encode(envelope)
        guard data.count <= Self.maximumPayloadBytes else {
            throw AgentLinkValidationError.oversizedPayload
        }
        return data
    }

    public func decode(_ data: Data, now: Date = Date()) throws -> AgentLinkEnvelope {
        guard data.count <= Self.maximumPayloadBytes else {
            throw AgentLinkValidationError.oversizedPayload
        }
        let envelope = try decoder.decode(AgentLinkEnvelope.self, from: data)
        try validate(envelope, now: now)
        return envelope
    }

    public func validate(_ envelope: AgentLinkEnvelope, now: Date) throws {
        guard envelope.protocolVersion == AgentLinkEnvelope.currentProtocolVersion else {
            throw AgentLinkValidationError.unsupportedProtocol(envelope.protocolVersion)
        }
        guard abs(now.timeIntervalSince(envelope.sentAt)) <= Self.maximumMessageAge else {
            throw AgentLinkValidationError.staleMessage
        }

        switch envelope.message {
        case let .pairingRequest(_, code):
            guard code.count == 6, code.allSatisfy(\.isNumber) else {
                throw AgentLinkValidationError.invalidPairingCode
            }
        case let .command(text):
            let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty, command.count <= 1_000 else {
                throw AgentLinkValidationError.invalidCommand
            }
        default:
            break
        }
    }
}
