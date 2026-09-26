import Foundation
import Testing
@testable import KaedeRemote

@Suite struct JevTests {
    let request = JevRequest(apiKey: "test-key").urlRequest(
        typed: "watashinoiflsgjdhfkf;a",
        ebiReading: "latalkgyrisoutekiniha",
        candidates: ["私の理想的には", "私の井相手きには"]
    )

    func body() throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func postsToSystemOneWithABearerKey() {
        #expect(request.url == URL(string: "https://api.typesafe.ai/v1/systemone"))
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
    }

    @Test func asksOneChoiceQuestionWithACriterionPerCandidate() throws {
        let body = try body()
        #expect(body["model"] as? String == "jev-latest")
        let state = try #require(body["state"] as? [String: String])
        #expect(state["typed"] == "watashinoiflsgjdhfkf;a")
        #expect(state["ebi_reading"] == "latalkgyrisoutekiniha")
        let questions = try #require(body["questions"] as? [String: Any])
        let sentence = try #require(questions["sentence"] as? [String: Any])
        #expect(sentence["type"] as? String == "choice")
        #expect(sentence["instructions"] is String)
        #expect(sentence["criteria"] as? [String: String] == ["c1": "私の理想的には", "c2": "私の井相手きには"])
    }

    @Test func readsTheChosenCandidate() throws {
        let data = Data(#"{"model":"jev-1.13","answers":{"sentence":{"type":"choice","choice":"c2","probabilities":{"c1":0.3,"c2":0.7},"confidence":0.7}}}"#.utf8)
        #expect(try JevResponse.choice(from: data, status: 200, candidates: ["a", "b"]) == "b")
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
            try JevResponse.choice(from: Data("{}".utf8), status: status, candidates: ["a", "b"])
        }
    }

    @Test func failsOnAChoiceThatWasNotOffered() {
        let data = Data(#"{"answers":{"sentence":{"type":"choice","choice":"c9"}}}"#.utf8)
        #expect(throws: JevError.unknownChoice("c9")) {
            try JevResponse.choice(from: data, status: 200, candidates: ["a", "b"])
        }
    }
}
