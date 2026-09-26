import Foundation
import Testing
@testable import KaedeConverter

/// The dictionary SwiftPM checked out with the package; `just bundle` copies the same directory.
private let checkedOutDictionary = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary")

@Suite struct AzooKeyConverterTests {
    let converter = AzooKeyConverter(
        dictionaryDirectory: checkedOutDictionary,
        memoryDirectory: FileManager.default.temporaryDirectory
    )

    @Test func convertsTatoeba() throws {
        #expect(try converter.convert(romaji: "tatoeba") == "例えば")
    }

    @Test func convertsHenkan() throws {
        #expect(try converter.convert(romaji: "henkan") == "変換")
    }

    @Test func readsCommaAndPeriodAsJapanesePunctuation() throws {
        let converted = try converter.convert(romaji: "hai,iie.")
        #expect(converted.contains("、"))
        #expect(converted.hasSuffix("。"))
    }

    @Test func completesADanglingNBeforePunctuation() throws {
        let converted = try converter.convert(romaji: "hon,")
        #expect(!converted.contains("n"))
        #expect(converted.hasSuffix("、"))
    }
}
