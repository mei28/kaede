import Testing
@testable import KaedeCore

private struct DictionaryConverter: KanaKanjiConverting {
    let table: [String: String]

    func convert(romaji: String) throws -> String {
        guard let converted = table[romaji] else { throw Unconvertible() }
        return converted
    }

    func candidates(romaji: String, limit: Int) throws -> [String] {
        [try convert(romaji: romaji)]
    }
}

private struct Unconvertible: Error {}

@Suite struct ReplacementTests {
    @Test func convertsRomajiPiecesAndKeepsVerbatimOnes() throws {
        let replacement = Replacement(typed: "", pieces: [
            .verbatim(" "), .romaji("tatoeba"), .verbatim("  "), .romaji("henkan"),
        ])
        let converter = DictionaryConverter(table: ["tatoeba": "例えば", "henkan": "変換"])
        #expect(try replacement.text(using: converter) == " 例えば  変換")
    }

    @Test func failsWhenTheConverterThrows() {
        let replacement = Replacement(typed: "", pieces: [.romaji("tatoeba"), .romaji("zzz")])
        let converter = DictionaryConverter(table: ["tatoeba": "例えば"])
        #expect(throws: Unconvertible.self) {
            try replacement.text(using: converter)
        }
    }

    @Test func rulesLineConverterConvertsWhatThePlannerConvertsAndKeepsTheRest() throws {
        let rules = RulesLineConverter(
            planner: EnterPlanner(lexicon: EnglishLexicon(wordList: "api\n")),
            converter: DictionaryConverter(table: ["tatoeba": "例えば"])
        )
        #expect(try rules.convert("api jajsd/a") == "api 例えば")
        #expect(try rules.convert("api") == "api")
    }

    @Test func candidatesStartWithTheConversionThenVaryOneChunkThenTheSplit() throws {
        let converter = ListConverter(table: [
            "hennkann": ["返還", "変換", "偏官", "編冠"],
            "tatoeba": ["例えば", "たとえば"],
            "hennkannoa": ["変換おあ"],
        ])
        let replacement = Replacement(typed: "", pieces: [.romaji("hennkann"), .verbatim(" "), .romaji("tatoeba")])
        let alternatives: [[ConversionPiece]] = [
            replacement.pieces,
            [.romaji("hennkannoa"), .verbatim(" "), .romaji("tatoeba")],
        ]
        #expect(try replacement.candidates(using: converter, alternatives: alternatives, limit: 8) == [
            "返還 例えば",
            // The 2nd and 3rd candidates of each chunk, one chunk at a time
            "変換 例えば", "偏官 例えば",
            "返還 たとえば",
            // Another split, converted with first candidates
            "変換おあ 例えば",
        ])
    }

    @Test func candidatesStopAtTheLimit() throws {
        let converter = ListConverter(table: ["hennkann": ["返還", "変換", "偏官"]])
        let replacement = Replacement(typed: "", pieces: [.romaji("hennkann")])
        #expect(try replacement.candidates(using: converter, alternatives: [], limit: 2) == ["返還", "変換"])
    }
}

/// Returns fixed candidate lists.
private struct ListConverter: KanaKanjiConverting {
    let table: [String: [String]]

    func convert(romaji: String) throws -> String {
        try candidates(romaji: romaji, limit: 1)[0]
    }

    func candidates(romaji: String, limit: Int) throws -> [String] {
        guard let list = table[romaji] else { throw Unconvertible() }
        return Array(list.prefix(limit))
    }
}
