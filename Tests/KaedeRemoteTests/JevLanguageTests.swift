import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

@Suite struct JevLanguageTests {
    let request = JevLanguageRequest(apiKey: "test-key").urlRequest(
        question: LanguageQuestion(typed: "are", ebiReading: "a.,", textBefore: "kore ha"),
        application: "com.github.wez.wezterm"
    )

    func body() throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func postsToSystemOneWithABearerKey() {
        #expect(request.url == URL(string: "https://api.typesafe.ai/v1/systemone"))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test func sendsTheKeysTheirEbiReadingTheTextBeforeAndTheApp() throws {
        let state = try #require(body()["state"] as? [String: String])
        #expect(state == [
            "typed_keys": "are",
            "ebi_reading": "a.,",
            "text_before_caret": "kore ha",
            "application": "com.github.wez.wezterm",
        ])
    }

    @Test func asksOneChoiceBetweenJapaneseEnglishAndKeep() throws {
        let questions = try #require(body()["questions"] as? [String: Any])
        let language = try #require(questions["language"] as? [String: Any])
        #expect(language["type"] as? String == "choice")
        #expect(language["instructions"] is String)
        let criteria = try #require(language["criteria"] as? [String: String])
        #expect(Set(criteria.keys) == ["ja", "en", "keep"])
    }

    func answer(_ choice: String, _ confidence: Double) -> Data {
        Data(#"{"answers":{"language":{"type":"choice","choice":"\#(choice)","confidence":\#(confidence)}}}"#.utf8)
    }

    @Test(arguments: [
        ("ja", 0.9, LanguageAnswer.japanese),
        ("en", 0.6, LanguageAnswer.english),
        ("keep", 0.95, LanguageAnswer.undecided),
        // Below 0.55 the rules decide
        ("ja", 0.5, LanguageAnswer.undecided),
    ])
    func readsTheChoiceAndItsConfidence(choice: String, confidence: Double, expected: LanguageAnswer) throws {
        #expect(try JevLanguageResponse.answer(from: answer(choice, confidence), status: 200) == expected)
    }

    @Test func failsOnAnHTTPErrorOrAnUnknownChoice() {
        #expect(throws: JevError.rateLimited) {
            try JevLanguageResponse.answer(from: Data("{}".utf8), status: 429)
        }
        #expect(throws: JevError.unknownChoice("fr")) {
            try JevLanguageResponse.answer(from: answer("fr", 0.9), status: 200)
        }
    }
}
