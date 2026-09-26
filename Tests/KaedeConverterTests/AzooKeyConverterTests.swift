import Foundation
import Testing
@testable import KaedeConverter

/// The dictionary SwiftPM checked out with the package; `just bundle` copies the same directory.
private let checkedOutDictionary = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: ".build/checkouts/AzooKeyKanaKanjiConverter/Sources/KanaKanjiConverterModuleWithDefaultDictionary/azooKey_dictionary_storage/Dictionary")

/// Downloaded by `just zenzai-model`, which `just test` runs first.
private let zenzaiWeight = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "Models/zenz-v3.1-small.gguf")

// Serialized: llama.cpp fails when several converters load the zenz weight at the same time
@Suite(.serialized) struct AzooKeyConverterTests {
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

    @Test(arguments: [
        ("henkan", "変換"),
        ("nihonngo", "日本語"),
        ("konnnakannjide", "こんな感じで"),
        // Without Zenzai the first candidate is 返還
        ("kitinntohennkann", "きちんと変換"),
    ])
    func convertsWithZenzai(romaji: String, expected: String) throws {
        let zenzai = AzooKeyConverter(
            dictionaryDirectory: checkedOutDictionary,
            memoryDirectory: FileManager.default.temporaryDirectory,
            zenzaiWeight: zenzaiWeight
        )
        let converted = try zenzai.convert(romaji: romaji)
        #expect(converted == expected)
    }

    @Test func failsWhenTheZenzaiWeightCannotBeLoaded() {
        // azooKey itself would quietly convert without Zenzai
        let zenzai = AzooKeyConverter(
            dictionaryDirectory: checkedOutDictionary,
            memoryDirectory: FileManager.default.temporaryDirectory,
            zenzaiWeight: URL(filePath: "/nonexistent/zenz.gguf")
        )
        #expect(throws: AzooKeyConverterError.self) {
            try zenzai.convert(romaji: "henkan")
        }
    }

    @Test func listsCandidatesWithTheFirstOneFirst() throws {
        let candidates = try converter.candidates(romaji: "kitinntohennkann", limit: 5)
        #expect(candidates.first == (try converter.convert(romaji: "kitinntohennkann")))
        #expect(candidates.contains("きちんと返還"))
        #expect(candidates.contains("きちんと変換"))
        #expect(candidates.count <= 5)
        #expect(Set(candidates).count == candidates.count)
    }
}
