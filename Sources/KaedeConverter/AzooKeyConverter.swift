import Foundation
import KaedeCore
import KanaKanjiConverterModule

public enum AzooKeyConverterError: Error, Equatable {
    case noCandidate(romaji: String)
}

/// Converts romaji with AzooKeyKanaKanjiConverter, taking the first candidate.
///
/// The dictionary directory is passed in rather than found through the library's
/// `withDefaultDictionary()`: its resource bundle must sit at the .app root, which codesign rejects.
public final class AzooKeyConverter: KanaKanjiConverting {
    private let converter: KanaKanjiConverter
    private let options: ConvertRequestOptions

    /// - Parameters:
    ///   - dictionaryDirectory: azooKey_dictionary_storage's `Dictionary` directory.
    ///   - memoryDirectory: required by the converter even though learning is off.
    public init(dictionaryDirectory: URL, memoryDirectory: URL) {
        converter = KanaKanjiConverter(dicdataStore: DicdataStore(dictionaryURL: dictionaryDirectory, preloadDictionary: true))
        options = ConvertRequestOptions(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: memoryDirectory,
            sharedContainerURL: memoryDirectory,
            textReplacer: .empty,
            specialCandidateProviders: nil,
            metadata: .init(versionString: "Kaede")
        )
    }

    public func convert(romaji: String) throws -> String {
        let composing = Self.composingText(for: romaji)
        defer { converter.stopComposition() }
        guard let first = converter.requestCandidates(composing, options: options).mainResults.first else {
            throw AzooKeyConverterError.noCandidate(romaji: romaji)
        }
        return first.text
    }

    /// The default roman2kana table has no entries for "," and ".", and leaves a final "n"
    /// unconverted until an IME commits it. Do both here, as committing would.
    private static func composingText(for romaji: String) -> ComposingText {
        var composing = ComposingText()
        var segment = ""
        func flushSegment() {
            composing.insertAtCursorPosition(segment, inputStyle: .roman2kana)
            if composing.convertTarget.last == "n" {
                composing.insertAtCursorPosition("n", inputStyle: .roman2kana)
            }
            segment = ""
        }
        for character in romaji {
            if let punctuation = japanesePunctuation[character] {
                flushSegment()
                composing.insertAtCursorPosition(punctuation, inputStyle: .direct)
            } else {
                segment.append(character)
            }
        }
        flushSegment()
        return composing
    }

    private static let japanesePunctuation: [Character: String] = [",": "、", ".": "。"]
}
