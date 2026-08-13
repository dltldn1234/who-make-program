import Foundation
#if canImport(Security)
import Security
#endif

public enum AgentIntelligenceError: LocalizedError, Sendable {
    case missingCredential
    case invalidResponse
    case service(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingCredential:
            "AI 연결 키가 없습니다. OPENAI_API_KEY 또는 JARVIS_AI_ENDPOINT를 설정해 주세요."
        case .invalidResponse:
            "AI 응답을 해석하지 못했습니다."
        case let .service(statusCode, message):
            "AI 서비스 오류(\(statusCode)): \(message)"
        }
    }
}

public struct AgentAIConfiguration: Equatable, Sendable {
    public let endpoint: URL
    public let apiKey: String?
    public let clientToken: String?
    public let model: String

    public init(endpoint: URL, apiKey: String?, clientToken: String? = nil, model: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.clientToken = clientToken
        self.model = model
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        let explicitEndpoint = environment["JARVIS_AI_ENDPOINT"].flatMap(URL.init(string:))
        let keychainToken = explicitEndpoint == nil ? JarvisRelayKeychain.clientToken() : nil
        let endpoint = explicitEndpoint
            ?? (keychainToken == nil ? nil : URL(string: "http://127.0.0.1:8787/v1/responses"))
            ?? URL(string: "https://api.openai.com/v1/responses")!
        return Self(
            endpoint: endpoint,
            apiKey: environment["OPENAI_API_KEY"],
            clientToken: environment["JARVIS_CLIENT_TOKEN"] ?? keychainToken,
            model: environment["OPENAI_MODEL"] ?? "gpt-5.6-terra"
        )
    }
}

private enum JarvisRelayKeychain {
    static func clientToken() -> String? {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.dltldn1234.jarvis.server",
            kSecAttrAccount as String: "client-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
#else
        return nil
#endif
    }
}

public actor OpenAIConversationClient {
    private let configuration: AgentAIConfiguration
    private let session: URLSession
    private var turns: [ConversationTurn] = []

    public init(
        configuration: AgentAIConfiguration = .fromEnvironment(),
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    public func answer(_ prompt: String) async throws -> String {
        if configuration.endpoint.host == "api.openai.com",
           configuration.apiKey?.isEmpty != false {
            throw AgentIntelligenceError.missingCredential
        }

        let conversation = (turns.suffix(6) + [ConversationTurn(role: "user", content: prompt)])
            .map { "\($0.role.uppercased()): \($0.content)" }
            .joined(separator: "\n")
        let body = ResponseRequest(
            model: configuration.model,
            instructions: "당신은 사용자의 개인 비서 JARVIS입니다. 한국어로 자연스럽고 간결하게 답하세요. 실행하지 않은 기기 동작을 실행했다고 말하지 마세요.",
            input: conversation,
            store: false
        )

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let clientToken = configuration.clientToken, !clientToken.isEmpty {
            request.setValue(clientToken, forHTTPHeaderField: "X-Jarvis-Client-Token")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentIntelligenceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let message = (try? JSONDecoder().decode(ServiceErrorEnvelope.self, from: data).error.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AgentIntelligenceError.service(statusCode: http.statusCode, message: message)
        }

        let decoded = try Self.decodeResponse(data)
        turns.append(ConversationTurn(role: "user", content: prompt))
        turns.append(ConversationTurn(role: "assistant", content: decoded))
        turns = Array(turns.suffix(8))
        return decoded
    }

    static func decodeResponse(_ data: Data) throws -> String {
        let response = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        let text = response.output
            .flatMap(\.content)
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AgentIntelligenceError.invalidResponse }
        return text
    }
}

private struct ConversationTurn: Sendable {
    let role: String
    let content: String
}

private struct ResponseRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
    let store: Bool
}

private struct ResponseEnvelope: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String
            let text: String?
        }
        let content: [Content]
    }
    let output: [Output]
}

private struct ServiceErrorEnvelope: Decodable {
    struct ServiceError: Decodable { let message: String }
    let error: ServiceError
}
