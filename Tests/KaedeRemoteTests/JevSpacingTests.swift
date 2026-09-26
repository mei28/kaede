import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

@Suite struct JevSpacingTests {
    let request = JevSpacingRequest(apiKey: "test-key").urlRequest(
        question: SpacingQuestion(typed: "localhost", respaced: "local host", textBefore: "curl "),
        application: "com.github.wez.wezterm"
    )

    func body() throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func sendsTheWordItsRespacingTheTextBeforeAndTheApp() throws {
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let state = try #require(body()["state"] as? [String: String])
        #expect(state == [
            "typed": "localhost",
            "respaced": "local host",
            "text_before_caret": "curl ",
            "application": "com.github.wez.wezterm",
        ])
    }

    @Test func asksOneChoiceBetweenRespaceKeepAndUndecided() throws {
        let questions = try #require(body()["questions"] as? [String: Any])
        let spacing = try #require(questions["spacing"] as? [String: Any])
        #expect(spacing["type"] as? String == "choice")
        let criteria = try #require(spacing["criteria"] as? [String: String])
        #expect(Set(criteria.keys) == ["respace", "keep", "undecided"])
    }

    func answer(_ choice: String, _ confidence: Double) -> Data {
        Data(#"{"answers":{"spacing":{"type":"choice","choice":"\#(choice)","confidence":\#(confidence)}}}"#.utf8)
    }

    @Test(arguments: [
        ("respace", 0.9, SpacingAnswer.respace),
        ("keep", 0.8, SpacingAnswer.keepAsTyped),
        ("undecided", 0.9, SpacingAnswer.undecided),
        ("keep", 0.4, SpacingAnswer.undecided),
    ])
    func readsTheChoiceAndItsConfidence(choice: String, confidence: Double, expected: SpacingAnswer) throws {
        #expect(try JevSpacingResponse.answer(from: answer(choice, confidence), status: 200) == expected)
    }

    @Test func failsOnAnHTTPError() {
        #expect(throws: JevError.overloaded) {
            try JevSpacingResponse.answer(from: Data("{}".utf8), status: 529)
        }
    }
}
