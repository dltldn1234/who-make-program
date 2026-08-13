import Foundation

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
    public let model: String

    public init(endpoint: URL, apiKey: String?, model: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        let endpoint = environment["JARVIS_AI_ENDPOINT"]
            .flatMap(URL.init(string:))
            ?? URL(string: "https://api.openai.com/v1/responses")!
        return Self(
            endpoint: endpoint,
            apiKey: environment["OPENAI_API_KEY"],
            model: environment["OPENAI_MODEL"] ?? "gpt-5.6-terra"
        )
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
