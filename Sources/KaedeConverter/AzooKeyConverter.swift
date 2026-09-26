import Foundation
import KaedeCore
import KanaKanjiConverterModule

public enum AzooKeyConverterError: Error, Equatable {
    case noCandidate(romaji: String)
    /// azooKey could not load the zenz weight; `status` is its own report.
    case zenzaiUnavailable(status: String)
}

/// Converts romaji with AzooKeyKanaKanjiConverter, taking the first candidate.
///
/// The dictionary directory is passed in rather than found through the library's
/// `withDefaultDictionary()`: its resource bundle must sit at the .app root, which codesign rejects.
public final class AzooKeyConverter: KanaKanjiConverting {
    private let converter: KanaKanjiConverter
    private let options: ConvertRequestOptions
    private let zenzaiWeight: URL?

    /// - Parameters:
    ///   - dictionaryDirectory: azooKey_dictionary_storage's `Dictionary` directory.
    ///   - memoryDirectory: required by the converter even though learning is off.
    ///   - zenzaiWeight: a zenz gguf file; when given, Zenzai (the neural converter) picks the kanji.
    public init(dictionaryDirectory: URL, memoryDirectory: URL, zenzaiWeight: URL? = nil) {
        converter = KanaKanjiConverter(dicdataStore: DicdataStore(dictionaryURL: dictionaryDirectory, preloadDictionary: true))
        self.zenzaiWeight = zenzaiWeight
        options = ConvertRequestOptions(
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            memoryDirectoryURL: memoryDirectory,
            sharedContainerURL: memoryDirectory,
            textReplacer: .empty,
            specialCandidateProviders: nil,
            // One inference is what the azooKey docs recommend for normal use
            zenzaiMode: zenzaiWeight.map {
                .on(weight: $0, inferenceLimit: 1, personalizationMode: nil, versionDependentMode: .v3(.init()))
            } ?? .off,
            metadata: .init(versionString: "Kaede")
        )
    }

    public func convert(romaji: String) throws -> String {
        try candidates(romaji: romaji, limit: 1)[0]
    }

    public func candidates(romaji: String, limit: Int) throws -> [String] {
        let composing = Self.composingText(for: romaji)
        defer { converter.stopComposition() }
        let results = converter.requestCandidates(composing, options: options)
        try checkZenzaiLoaded()
        var texts: [String] = []
        for candidate in results.mainResults where !texts.contains(candidate.text) {
            texts.append(candidate.text)
            if texts.count == limit { break }
        }
        guard !texts.isEmpty else {
            throw AzooKeyConverterError.noCandidate(romaji: romaji)
        }
        return texts
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

    /// azooKey converts without Zenzai when the weight fails to load, reporting it only in
    /// `zenzStatus` ("load <url>" on success, the error appended on failure).
    private func checkZenzaiLoaded() throws {
        guard let zenzaiWeight else { return }
        let loaded = "load \(zenzaiWeight.absoluteString)"
        guard converter.zenzStatus == loaded else {
            throw AzooKeyConverterError.zenzaiUnavailable(status: converter.zenzStatus)
        }
    }
}
