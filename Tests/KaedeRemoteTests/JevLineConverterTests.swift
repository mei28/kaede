import Foundation
import KaedeCore
import Testing
@testable import KaedeRemote

/// Converts romaji to itself in uppercase, so the candidate sentences are easy to predict.
struct UppercaseConverter: KanaKanjiConverting {
    func convert(romaji: String) throws -> String { romaji.uppercased() }
}

@Suite struct JevLineConverterTests {
    let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: ""))

    func jev(answering choice: String, transport: CannedTransport? = nil) -> (JevLineConverter<UppercaseConverter>, CannedTransport) {
        let transport = transport ?? CannedTransport(data: Data(#"{"answers":{"sentence":{"type":"choice","choice":"\#(choice)"}}}"#.utf8))
        return (JevLineConverter(request: JevRequest(apiKey: "k"), planner: planner, converter: UppercaseConverter(), transport: transport), transport)
    }

    @Test func offersTheAlternativeSentencesAndReturnsTheChosenOne() async throws {
        let (converter, transport) = jev(answering: "c2")
        // The best split is watashino|risoutekiniha; the runner-up is watashinoi|isoutekiniha
        let chosen = try await converter.convert("watashinoiflsgjdhfkf;a")
        let body = String(decoding: try #require(transport.sent.first?.httpBody), as: UTF8.self)
        #expect(body.contains("WATASHINORISOUTEKINIHA"))
        #expect(chosen != "WATASHINORISOUTEKINIHA")
    }

    @Test func doesNotAskWhenThereIsOnlyOneCandidate() async throws {
        let (converter, transport) = jev(answering: "c1")
        // ";" is neither a letter nor romaji in QWERTY, so only the Ebi reading "haha" covers the keys
        #expect(try await converter.convert(";a;a") == "HAHA")
        #expect(transport.sent.isEmpty)
    }
}
