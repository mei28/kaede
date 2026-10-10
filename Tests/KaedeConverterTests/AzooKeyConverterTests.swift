import Foundation
import KaedeCore
import Testing
@testable import KaedeConverter

/// The dictionary SwiftPM checked out with the package; `just bundle` copies the same directory.
let checkedOutDictionary = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary")

@Suite struct AzooKeyConverterTests {
    let converter = AzooKeyConverter(
        dictionaryDirectory: checkedOutDictionary,
        memoryDirectory: FileManager.default.temporaryDirectory
    )

    // Without Zenzai azooKey ranks some readings oddly (強は over 今日は, 10次 over 10時), so
    // these are lines it gets right; Kaede takes its first candidate as it is
    @Test(arguments: [
        ("tatoeba", "例えば"),
        ("henkan", "変換"),
        ("watashinonamaeha", "私の名前は"),
        ("kinounoare", "昨日のあれ"),
    ])
    func convertsRomaji(romaji: String, expected: String) throws {
        let converted = try converter.convert(romaji: romaji).map(\.text).joined()
        #expect(converted == expected)
    }

    @Test func completesADanglingN() throws {
        #expect(try converter.convert(romaji: "hon").map(\.text).joined() == "本")
    }

    @Test func readsAHyphenAsALongVowel() throws {
        #expect(try converter.convert(romaji: "ra-men").map(\.text).joined() == "ラーメン")
    }

    @Test func givesAClauseAsOnePhraseWithItsReading() throws {
        #expect(try converter.convert(romaji: "kyouhatenkigaii") == [Bunsetsu(reading: "きょうはてんきがいい", text: "強は天気がいい")])
    }

    @Test func listsCandidatesForAReadingOfThatLength() throws {
        let candidates = try converter.candidates(reading: "きょうは")
        #expect(candidates.contains("今日は"))
        #expect(candidates.contains("強は"))
        #expect(candidates.contains("きょうは"))
        #expect(candidates.contains("キョウハ"))
        // 今日 reads きょう: it would leave は behind
        #expect(!candidates.contains("今日"))
        #expect(Set(candidates).count == candidates.count)
    }

    @Test func findsTheLettersAPhraseCameFrom() {
        #expect(converter.romaji(of: "kyouhaweare", reading: 4..<8) == "weare")
        #expect(converter.romaji(of: "kyouhaweare", reading: 0..<4) == "kyouha")
        #expect(converter.romaji(of: "ra-men", reading: 0..<4) == "ra-men")
    }

    @Test func findsNoLettersForAReadingThatSplitsASpelling() {
        // ん of "tenki" is only settled by the k after it
        #expect(converter.romaji(of: "tenki", reading: 0..<2) == nil)
    }

    @Test func keepsDigitsHalfWidth() throws {
        let converted = try converter.convert(romaji: "10ji").map(\.text).joined()
        #expect(converted.hasPrefix("10"))
        #expect(!converted.contains("じ"))
    }
}
