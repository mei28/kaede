import Foundation
import Testing
@testable import KaedeRemote

@Suite struct ClaudeResponseTests {
    func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    @Test func readsTheTextFieldOfTheJSONAnswer() throws {
        let data = try json([
            "stop_reason": "end_turn",
            "content": [["type": "text", "text": #"{"text":"例えば"}"#]],
        ])
        #expect(try ClaudeResponse.text(from: data, status: 200) == "例えば")
    }

    @Test func skipsThinkingBlocksBeforeTheAnswer() throws {
        let data = try json([
            "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": #"{"text":"変換"}"#]],
        ])
        #expect(try ClaudeResponse.text(from: data, status: 200) == "変換")
    }

    @Test func failsOnARefusal() throws {
        let data = try json(["stop_reason": "refusal", "content": []])
        #expect(throws: ClaudeError.refused) {
            try ClaudeResponse.text(from: data, status: 200)
        }
    }

    @Test func failsWhenTheAnswerWasCutOff() throws {
        let data = try json(["stop_reason": "max_tokens", "content": [["type": "text", "text": #"{"te"#]]])
        #expect(throws: ClaudeError.truncated) {
            try ClaudeResponse.text(from: data, status: 200)
        }
    }

    @Test func failsWithTheStatusAndBodyOnAnHTTPError() throws {
        let data = Data(#"{"type":"error","error":{"type":"authentication_error"}}"#.utf8)
        #expect(throws: ClaudeError.http(status: 401, body: #"{"type":"error","error":{"type":"authentication_error"}}"#)) {
            try ClaudeResponse.text(from: data, status: 401)
        }
    }
}
