import Foundation
import KaedeCore
import KanaKanjiConverterModule

public enum AzooKeyConverterError: Error, Equatable {
    case noCandidate(romaji: String)
    case noCandidateForReading(String)
}

/// Converts romaji to Japanese with AzooKeyKanaKanjiConverter, taking its first candidate.
///
/// The dictionary directory is passed in rather than found through the library's
/// `withDefaultDictionary()`: its resource bundle must sit at the .app root, which codesign rejects.
/// Not Sendable: azooKey's converter keeps its lattice between calls.
public final class AzooKeyConverter {
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
            specialCandidateProviders: [],
            metadata: .init(versionString: "Kaede")
        )
    }

    /// The first candidate for a clause of romaji (letters, "-" for ー, and digits), as one
    /// phrase: as in azooKey itself, the user splits it into phrases when choosing.
    ///
    /// azooKey's candidates cannot be split into phrases: their words cross phrase borders
    /// (強 | は天気 | がいい for 強は天気がいい).
    public func convert(romaji: String) throws -> [Bunsetsu] {
        // The next request would otherwise build on this one's input
        defer { converter.stopComposition() }
        let composing = Self.composingText(for: romaji)
        let results = converter.requestCandidates(composing, options: options)
        guard let first = results.mainResults.first else {
            throw AzooKeyConverterError.noCandidate(romaji: romaji)
        }
        return [Bunsetsu(reading: composing.convertTarget, text: first.text)]
    }

    /// The candidates for a reading on its own, each reading all of it: the choices for one phrase.
    public func candidates(reading: String) throws -> [String] {
        defer { converter.stopComposition() }
        var composing = ComposingText()
        composing.insertAtCursorPosition(reading, inputStyle: .direct)
        let results = converter.requestCandidates(composing, options: options)
        var texts: [String] = []
        // Words that read only the start (今日 for きょうは) would drop the rest of the phrase
        for candidate in results.mainResults where candidate.rubyCount == reading.count && !texts.contains(candidate.text) {
            texts.append(candidate.text)
        }
        guard !texts.isEmpty else {
            throw AzooKeyConverterError.noCandidateForReading(reading)
        }
        return texts
    }

    /// The default roman2kana table has no "-" and leaves a final "n" unconverted until an IME
    /// commits it. Do both here, as committing would.
    private static func composingText(for romaji: String) -> ComposingText {
        var composing = ComposingText()
        composing.insertAtCursorPosition(romaji.replacing("-", with: "ー"), inputStyle: .roman2kana)
        if composing.convertTarget.last == "n" {
            composing.insertAtCursorPosition("n", inputStyle: .roman2kana)
        }
        return composing
    }
}
