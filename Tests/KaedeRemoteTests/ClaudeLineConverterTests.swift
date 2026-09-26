import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

/// Answers every request with one canned response and remembers what was sent.
final class CannedTransport: HTTPTransport, @unchecked Sendable {
    let data: Data
    let status: Int
    private(set) var sent: [URLRequest] = []

    init(data: Data, status: Int = 200) {
        self.data = data
        self.status = status
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        sent.append(request)
        return (data, status)
    }
}

private struct FixedProposal: LineConverting {
    func convert(_ typed: String) async throws -> String { "はまだて" }
}

@Suite struct ClaudeLineConverterTests {
    @Test func sendsTheEbiReadingAndTheRuleProposalAndReturnsClaudesSentence() async throws {
        let transport = CannedTransport(data: Data(#"{"stop_reason":"end_turn","content":[{"type":"text","text":"{\"text\":\"はまだ\"}"}]}"#.utf8))
        let claude = ClaudeLineConverter(
            request: ClaudeRequest(apiKey: "k", model: "claude-opus-5", effort: "low"),
            proposal: FixedProposal(),
            transport: transport
        )
        #expect(try await claude.convert(";a,amajd") == "はまだ")
        let body = String(decoding: try #require(transport.sent.first?.httpBody), as: UTF8.self)
        #expect(body.contains("hamadate"))  // ";a,amajd" read in Ebi
        #expect(body.contains("はまだて"))
    }
}
