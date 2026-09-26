import Foundation
import KaedeCore

/// Converts a typed line word by word as the app does on each Space, asking Jev about the
/// words `EnterPlanner.question(for:)` doubts. For comparing on the corpus; the app asks in
/// the event tap.
public struct JevLanguageLineConverter<Converter: KanaKanjiConverting>: LineConverting {
    let jev: Jev
    let planner: EnterPlanner
    let converter: Converter
    let transport: any HTTPTransport

    public init(jev: Jev, planner: EnterPlanner, converter: Converter, transport: any HTTPTransport) {
        self.jev = jev
        self.planner = planner
        self.converter = converter
        self.transport = transport
    }

    public func convert(_ typed: String) async throws -> String {
        var converted: [String] = []
        var recent = ""
        for word in typed.split(separator: " ", omittingEmptySubsequences: false).map(String.init) {
            let run = Run(typing: word)
            var language: Language?
            var spacing: Spacing?
            switch planner.question(for: run) {
            case let .spacing(respaced):
                spacing = try await askSpacing(SpacingQuestion(typed: word, respaced: respaced, textBefore: recent))
            case let .language(ruleReading):
                language = try await askLanguage(LanguageQuestion(
                    typed: word, ebiReading: run.reading(in: .ebi), textBefore: recent, ruleReading: ruleReading
                ))
            case nil:
                break
            }
            switch planner.plan(run, preferring: language, spacing: spacing) {
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
    private func askLanguage(_ question: LanguageQuestion) async throws -> Language? {
        let (data, status) = try await transport.send(jev.language.urlRequest(question: question, application: "KaedeEval"))
        switch try JevLanguageResponse.answer(from: data, status: status) {
        case .japanese: return .japanese
        case .english: return .english
        case .undecided: return nil
        case .failed: preconditionFailure("a response is never read as failed; errors throw")
        }
    }

    /// Jev's spacing for the word, or nil when it cannot tell (the rules respace it).
    private func askSpacing(_ question: SpacingQuestion) async throws -> Spacing? {
        let (data, status) = try await transport.send(jev.spacing.urlRequest(question: question, application: "KaedeEval"))
        switch try JevSpacingResponse.answer(from: data, status: status) {
        case .respace: return .respace
        case .keepAsTyped: return .keepAsTyped
        case .undecided: return nil
        case .failed: preconditionFailure("a response is never read as failed; errors throw")
        }
    }
}
