import Foundation
import Testing
@testable import AgentIntelligence

@Suite("OpenAI conversation response decoding")
struct OpenAIConversationClientTests {
    @Test("Collects output text across response items")
    func decodesOutputText() throws {
        let data = Data(#"{"output":[{"content":[{"type":"output_text","text":"안녕하세요."}]},{"content":[{"type":"output_text","text":"무엇을 도와드릴까요?"}]}]}"#.utf8)

        #expect(try OpenAIConversationClient.decodeResponse(data) == "안녕하세요.\n무엇을 도와드릴까요?")
    }

    @Test("Rejects responses without speakable text")
    func rejectsEmptyOutput() {
        let data = Data(#"{"output":[{"content":[{"type":"reasoning","text":null}]}]}"#.utf8)

        #expect(throws: AgentIntelligenceError.self) {
            try OpenAIConversationClient.decodeResponse(data)
        }
    }

    @Test("Environment configuration never embeds a credential")
    func environmentConfiguration() {
        let configuration = AgentAIConfiguration.fromEnvironment([
            "JARVIS_AI_ENDPOINT": "https://jarvis.example.com/respond",
            "OPENAI_MODEL": "test-model"
        ])

        #expect(configuration.endpoint.absoluteString == "https://jarvis.example.com/respond")
        #expect(configuration.model == "test-model")
        #expect(configuration.apiKey == nil)
    }
}
