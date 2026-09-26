import Foundation
import KaedeCore

/// Converts the plan and its alternatives, and lets Jev choose among the sentences when
/// there is more than one. Jev decides routing only; typos stay as typed.
public struct JevLineConverter<Converter: KanaKanjiConverting>: LineConverting {
    /// Splits tried per token when building alternatives.
    static var perToken: Int { 3 }
    /// Jev accepts up to 255 options; a handful keeps the request small and the choice sharp.
    static var maxCandidates: Int { 6 }

    let request: JevRequest
    let planner: EnterPlanner
    let converter: Converter
    let transport: any HTTPTransport

    public init(request: JevRequest, planner: EnterPlanner, converter: Converter, transport: any HTTPTransport) {
        self.request = request
        self.planner = planner
        self.converter = converter
        self.transport = transport
    }

    public func convert(_ typed: String) async throws -> String {
        let run = Run(typing: typed)
        var candidates: [String] = []
        for pieces in planner.alternatives(for: run, perToken: Self.perToken) {
            let sentence = try Replacement(typed: typed, pieces: pieces).text(using: converter)
            if !candidates.contains(sentence) {
                candidates.append(sentence)
            }
            if candidates.count == Self.maxCandidates { break }
        }
        switch candidates.count {
        case 0: return typed  // the run passes: nothing on screen changes
        case 1: return candidates[0]  // nothing to choose from, so do not ask
        default:
            let urlRequest = request.urlRequest(typed: typed, ebiReading: run.reading(in: .ebi), candidates: candidates)
            let (data, status) = try await transport.send(urlRequest)
            return try JevResponse.choice(from: data, status: status, candidates: candidates)
        }
    }
}
