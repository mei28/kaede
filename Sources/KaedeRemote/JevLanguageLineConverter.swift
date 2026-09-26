import Foundation
import KaedeCore

/// Converts a typed line word by word as the app does on each Space, asking Jev the language
/// of ambiguous words. For comparing on the corpus; the app asks in the event tap.
public struct JevLanguageLineConverter<Converter: KanaKanjiConverting>: LineConverting {
    let request: JevLanguageRequest
    let planner: EnterPlanner
    let converter: Converter
    let transport: any HTTPTransport

    public init(request: JevLanguageRequest, planner: EnterPlanner, converter: Converter, transport: any HTTPTransport) {
        self.request = request
        self.planner = planner
        self.converter = converter
        self.transport = transport
    }

    public func convert(_ typed: String) async throws -> String {
        var converted: [String] = []
        var recent = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: false).map(String.init) {
            let run = Run(typing: word)
            let language = planner.isAmbiguous(run) ? try await askLanguage(of: run, after: recent) : nil
            switch planner.plan(run, preferring: language) {
            case .pass:
                converted.append(word)
            case let .convert(pieces):
                converted.append(try Replacement(typed: word, pieces: pieces).text(using: converter))
            }
            recent = String((recent + word + " ").suffix(KeyEngine.recentTextLimit))
        }
        return converted.joined(separator: " ")
    }

    /// Jev's language for the word, or nil when it cannot tell (the rules decide).
    private func askLanguage(of run: Run, after recent: String) async throws -> Language? {
        let question = LanguageQuestion(typed: run.screenText, ebiReading: run.reading(in: .ebi), textBefore: recent)
        let (data, status) = try await transport.send(request.urlRequest(question: question, application: "KaedeEval"))
        switch try JevLanguageResponse.answer(from: data, status: status) {
        case .japanese: return .japanese
        case .english: return .english
        case .undecided: return nil
        case .failed: preconditionFailure("a response is never read as failed; errors throw")
        }
    }
}
