import Foundation
import KaedeCore

/// Asks Claude for the sentence the user meant, giving it the typed keys, their Ebi reading
/// and the rule-based conversion as a starting point.
public struct ClaudeLineConverter<Proposal: LineConverting>: LineConverting {
    let request: ClaudeRequest
    let proposal: Proposal
    let transport: any HTTPTransport

    public init(request: ClaudeRequest, proposal: Proposal, transport: any HTTPTransport) {
        self.request = request
        self.proposal = proposal
        self.transport = transport
    }

    public func convert(_ typed: String) async throws -> String {
        let urlRequest = request.urlRequest(
            typed: typed,
            ebiReading: Run(typing: typed).reading(in: .ebi),
            proposal: try await proposal.convert(typed)
        )
        let (data, status) = try await transport.send(urlRequest)
        return try ClaudeResponse.text(from: data, status: status)
    }
}
