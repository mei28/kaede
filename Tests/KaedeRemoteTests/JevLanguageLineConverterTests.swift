import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

/// Converts romaji to itself in uppercase, so the candidate sentences are easy to predict.
struct UppercaseConverter: KanaKanjiConverting {
    func convert(romaji: String) throws -> String { romaji.uppercased() }
    func candidates(romaji: String, limit: Int) throws -> [String] { [romaji.uppercased()] }
}

@Suite struct JevLanguageLineConverterTests {
    let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "are\nthe\n"))

    func converter(answering choice: String) -> (JevLanguageLineConverter<UppercaseConverter>, CannedTransport) {
        let transport = CannedTransport(data: Data(#"{"answers":{"language":{"type":"choice","choice":"\#(choice)","confidence":0.9}}}"#.utf8))
        return (JevLanguageLineConverter(request: JevLanguageRequest(apiKey: "k"), planner: planner, converter: UppercaseConverter(), transport: transport), transport)
    }

    @Test func asksOnlyAboutAmbiguousWordsAndFollowsTheAnswer() async throws {
        let (japanese, transport) = converter(answering: "ja")
        #expect(try await japanese.convert("the are jajsd/a") == "the ARE TATOEBA")
        #expect(transport.sent.count == 1)  // only "are" is ambiguous

        let (english, _) = converter(answering: "en")
        #expect(try await english.convert("the are jajsd/a") == "the are TATOEBA")
    }

    @Test func sendsTheWordsBeforeAsContext() async throws {
        let (japanese, transport) = converter(answering: "ja")
        _ = try await japanese.convert("the are")
        let body = String(decoding: try #require(transport.sent.first?.httpBody), as: UTF8.self)
        #expect(body.contains(#""text_before_caret":"the ""#))
    }
}
