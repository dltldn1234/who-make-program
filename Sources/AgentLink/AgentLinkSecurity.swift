import CryptoKit
import Foundation
import Security

public struct AgentLinkCredential: Codable, Equatable, Sendable {
    public let id: UUID
    public let peer: AgentDeviceIdentity
    public let secret: Data

    public init(id: UUID = UUID(), peer: AgentDeviceIdentity, secret: Data) {
        self.id = id
        self.peer = peer
        self.secret = secret
    }

    public static func generate(for peer: AgentDeviceIdentity) throws -> Self {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AgentLinkSecurityError.randomGenerationFailed(status)
        }
        return Self(peer: peer, secret: Data(bytes))
    }
}

public enum AgentLinkSecurityError: Error, Equatable, Sendable {
    case randomGenerationFailed(OSStatus)
    case keychain(OSStatus)
    case invalidCredential
}

public enum AgentLinkPairingKey {
    public static func derive(from code: String) throws -> Data {
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            throw AgentLinkValidationError.invalidPairingCode
        }
        return Data(SHA256.hash(data: Data("agent-link-pairing-v1:\(code)".utf8)))
    }
}

public struct AgentLinkTrustStore: Sendable {
    private static let service = "com.dltldn1234.agent.link.trust"
    private static let account = "trusted-companion"

    public init() {}

    public func load() throws -> AgentLinkCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AgentLinkSecurityError.keychain(status)
        }
        guard let data = result as? Data,
              let credential = try? JSONDecoder().decode(AgentLinkCredential.self, from: data),
              credential.secret.count == 32 else {
            throw AgentLinkSecurityError.invalidCredential
        }
        return credential
    }

    public func save(_ credential: AgentLinkCredential) throws {
        guard credential.secret.count == 32 else {
            throw AgentLinkSecurityError.invalidCredential
        }
        let data = try JSONEncoder().encode(credential)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AgentLinkSecurityError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw AgentLinkSecurityError.keychain(updateStatus)
        }
    }

    public func remove() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AgentLinkSecurityError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
    }
}
