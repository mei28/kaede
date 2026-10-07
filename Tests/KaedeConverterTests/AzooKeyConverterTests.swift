import Foundation
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
        let converted = try converter.convert(romaji: romaji)
        #expect(converted == expected)
    }

    @Test func completesADanglingN() throws {
        #expect(try converter.convert(romaji: "hon") == "本")
    }

    @Test func readsAHyphenAsALongVowel() throws {
        #expect(try converter.convert(romaji: "ra-men") == "ラーメン")
    }

    @Test func keepsDigitsHalfWidth() throws {
        let converted = try converter.convert(romaji: "10ji")
        #expect(converted.hasPrefix("10"))
        #expect(!converted.contains("じ"))
    }
}
