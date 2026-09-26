import Foundation
import Testing
@testable import KaedeRemote

@Suite struct ClaudeRequestTests {
    let request = ClaudeRequest(apiKey: "test-key", model: "claude-opus-5", effort: "low").urlRequest(
        typed: "api;a,amajd",
        ebiReading: "aprhamadate",
        proposal: "apiはまだて"
    )

    func body() throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func postsToTheMessagesAPIWithTheKeyAndVersion() {
        #expect(request.url == URL(string: "https://api.anthropic.com/v1/messages"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func sendsTheTypedLineItsEbiReadingAndTheRuleProposalAsData() throws {
        let messages = try #require(body()["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? String)
        #expect(messages.first?["role"] as? String == "user")
        #expect(content.contains("api;a,amajd"))
        #expect(content.contains("aprhamadate"))
        #expect(content.contains("apiはまだて"))
        #expect(try body()["system"] is String)
    }

    @Test func asksForJSONWithOneTextFieldAtTheGivenModelAndEffort() throws {
        let body = try body()
        #expect(body["model"] as? String == "claude-opus-5")
        let outputConfig = try #require(body["output_config"] as? [String: Any])
        #expect(outputConfig["effort"] as? String == "low")
        let format = try #require(outputConfig["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["required"] as? [String] == ["text"])
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test func letsTheServerFallBackToAnotherModelOnARefusal() throws {
        #expect(request.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
        #expect(try body()["fallbacks"] as? String == "default")
    }
}
