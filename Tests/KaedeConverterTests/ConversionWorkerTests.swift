import Foundation
import KaedeCore
import Testing
@testable import KaedeConverter

/// The word lists in the repository's Resources/, which `just bundle` copies into the app.
private let bundledWordLists = ["en10k.txt", "extra-words.txt"].map { name in
    URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Resources/\(name)").path(percentEncoded: false)
}

/// One worker for the suite: loading azooKey's dictionary takes about a second.
private let worker = ConversionWorker(
    dictionaryDirectory: checkedOutDictionary,
    memoryDirectory: FileManager.default.temporaryDirectory,
    lexicon: try! EnglishLexicon(contentsOfFiles: bundledWordLists)
)

@Suite struct ConversionWorkerTests {
    @Test(arguments: [
        ("kyouhagoogledekensaku", "今日は google で検索"),
        ("pythonnobug", "python の bug"),
        ("python no bug", "python の bug"),
        ("sikasinoatoallyouneedislove", "しかしのあと all you need is love"),
        ("thisisapen.", "this is a pen."),
        ("watashinonamaeha", "私の名前は"),
        ("kinouno are", "昨日のあれ"),
        ("I want to go to the park", "I want to go to the park"),
        ("how to use", "how to use"),
        ("kubernetes", "kubernetes"),
        ("grokga", "grok が"),
        ("ra-men", "ラーメン"),
    ])
    func convertsALine(typed: String, expected: String) async throws {
        let converted = try await worker.convert(typed, style: .touten)
        #expect(converted == expected)
    }

    @Test func convertsSeveralLines() async throws {
        let converted = try await worker.convert("watashinonamaeha\nthisisapen.", style: .touten)
        #expect(converted == "私の名前は\nthis is a pen.")
    }

    @Test func writesJapanesePunctuationInTheStyleAsked() async throws {
        let converted = try await worker.convert("watashinonamaeha,kinounoare.", style: .fullWidthCommaPeriod)
        #expect(converted == "私の名前は，昨日のあれ．")
    }

    @Test func stopsWhenCancelled() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await worker.convert("watashinonamaeha", style: .touten)
        }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
