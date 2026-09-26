import Testing
@testable import KaedeCore

private struct DictionaryConverter: KanaKanjiConverting {
    let table: [String: String]

    func convert(romaji: String) throws -> String {
        guard let converted = table[romaji] else { throw Unconvertible() }
        return converted
    }
}

private struct Unconvertible: Error {}

@Suite struct ReplacementTests {
    @Test func convertsRomajiPiecesAndKeepsVerbatimOnes() throws {
        let replacement = Replacement(deleteCount: 0, pieces: [
            .verbatim(" "), .romaji("tatoeba"), .verbatim("  "), .romaji("henkan"),
        ])
        let converter = DictionaryConverter(table: ["tatoeba": "例えば", "henkan": "変換"])
        #expect(try replacement.text(using: converter) == " 例えば  変換")
    }

    @Test func failsWhenTheConverterThrows() {
        let replacement = Replacement(deleteCount: 0, pieces: [.romaji("tatoeba"), .romaji("zzz")])
        let converter = DictionaryConverter(table: ["tatoeba": "例えば"])
        #expect(throws: Unconvertible.self) {
            try replacement.text(using: converter)
        }
    }
}
