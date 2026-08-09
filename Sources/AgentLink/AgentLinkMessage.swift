import Foundation

public enum AgentDeviceKind: String, Codable, Sendable {
    case mac
    case iPhone
}

public struct AgentDeviceIdentity: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: AgentDeviceKind

    public init(id: UUID, name: String, kind: AgentDeviceKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public enum AgentLinkMessage: Codable, Equatable, Sendable {
    case pairingRequest(device: AgentDeviceIdentity, code: String)
    case pairingAccepted(device: AgentDeviceIdentity)
    case command(text: String)
    case approval(id: UUID, approved: Bool)
    case status(state: String)
    case heartbeat
    case error(code: String, message: String)
}

public struct AgentLinkEnvelope: Codable, Equatable, Sendable {
    public static let currentProtocolVersion = 1

    public let protocolVersion: Int
    public let id: UUID
    public let sentAt: Date
    public let message: AgentLinkMessage

    public init(
        protocolVersion: Int = currentProtocolVersion,
        id: UUID = UUID(),
        sentAt: Date = Date(),
        message: AgentLinkMessage
    ) {
        self.protocolVersion = protocolVersion
        self.id = id
        self.sentAt = sentAt
        self.message = message
    }
}
