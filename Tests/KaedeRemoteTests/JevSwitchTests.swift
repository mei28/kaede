import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

@Suite struct JevSwitchTests {
    let question = Question(
        id: 1, keys: "jajs", ebiReading: "tato", textBefore: "kore ",
        options: [.english, .japaneseEbi, .keep]
    )
    let roman = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"

    func body(of request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    var request: URLRequest {
        JevSwitchRequest(apiKey: "test-key").urlRequest(question: question, application: "com.github.wez.wezterm", inputSource: roman)
    }

    @Test func postsToSystemOneWithABearerKeyAndGivesUpAfterTwoSeconds() {
        #expect(request.url == URL(string: "https://api.typesafe.ai/v1/systemone"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.timeoutInterval == 2)
    }

    @Test func sendsTheKeysTheirEbiReadingTheTextBeforeTheAppAndTheSource() throws {
        let state = try #require(body(of: request)["state"] as? [String: String])
        #expect(state == [
            "typed_keys": "jajs",
            "ebi_reading": "tato",
            "text_before_caret": "kore ",
            "application": "com.github.wez.wezterm",
            "input_source": roman,
        ])
    }

    @Test func leavesOutAnUnknownApp() throws {
        let request = JevSwitchRequest(apiKey: "k").urlRequest(question: question, application: nil, inputSource: roman)
        let state = try #require(body(of: request)["state"] as? [String: String])
        #expect(state["application"] == nil)
    }

    @Test func asksOneChoiceAmongTheOfferedAnswers() throws {
        let questions = try #require(body(of: request)["questions"] as? [String: Any])
        let mode = try #require(questions["mode"] as? [String: Any])
        #expect(mode["type"] as? String == "choice")
        #expect(mode["instructions"] is String)
        let criteria = try #require(mode["criteria"] as? [String: String])
        #expect(Set(criteria.keys) == ["english", "japanese_ebi", "keep"])
    }

    func response(_ choice: String, _ confidence: Double, usage: String = #","usage":{"input_tokens":990,"output_tokens":53}"#) -> Data {
        Data(#"{"answers":{"mode":{"type":"choice","choice":"\#(choice)","confidence":\#(confidence)}}\#(usage)}"#.utf8)
    }

    @Test func readsTheChoiceItsConfidenceAndTheInputTokens() throws {
        let (judgment, inputTokens) = try JevSwitchResponse.read(response("japanese_ebi", 0.8), status: 200, offered: question.options)
        #expect(judgment == Judgment(answer: .japaneseEbi, confidence: 0.8))
        #expect(inputTokens == 990)
    }

    @Test func failsOnAChoiceThatWasNotOffered() {
        #expect(throws: JevError.unknownChoice("japanese_qwerty")) {
            try JevSwitchResponse.read(response("japanese_qwerty", 0.8), status: 200, offered: question.options)
        }
    }

    @Test func failsOnAConfidenceOutsideZeroToOne() {
        #expect(throws: JevError.unexpectedConfidence(1.5)) {
            try JevSwitchResponse.read(response("keep", 1.5), status: 200, offered: question.options)
        }
    }

    @Test func failsWithoutTheUsage() {
        #expect(throws: DecodingError.self) {
            try JevSwitchResponse.read(response("keep", 0.8, usage: ""), status: 200, offered: question.options)
        }
    }

    @Test(arguments: [
        (401, JevError.unauthorized),
        (422, JevError.invalidRequest(body: "{}")),
        (429, JevError.rateLimited),
        (529, JevError.overloaded),
        (500, JevError.http(status: 500, body: "{}")),
    ])
    func failsWithAnErrorPerStatus(status: Int, error: JevError) {
        #expect(throws: error) {
            try JevSwitchResponse.read(Data("{}".utf8), status: status, offered: question.options)
        }
    }
}
