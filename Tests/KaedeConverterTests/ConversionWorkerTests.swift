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
        // Names of the user's own tools, from extra-words.txt
        ("githubnipushshita", "github に push した"),
        ("kyouhaclaudetohanashita", "今日は claude と話した"),
    ])
    func convertsALine(typed: String, expected: String) async throws {
        let converted = try await worker.convert(typed, style: .touten).text
        #expect(converted == expected)
    }

    @Test func convertsSeveralLines() async throws {
        let converted = try await worker.convert("watashinonamaeha\nthisisapen.", style: .touten).text
        #expect(converted == "私の名前は\nthis is a pen.")
    }

    @Test func writesJapanesePunctuationInTheStyleAsked() async throws {
        let converted = try await worker.convert("watashinonamaeha,kinounoare.", style: .fullWidthCommaPeriod).text
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

@Suite struct ConversionWorkerChoosingTests {
    private func unit(_ kind: ConversionUnit.Kind, reading: String) -> ConversionUnit {
        ConversionUnit(kind: kind, text: "", reading: reading, range: 0..<0, line: 0)
    }

    @Test func listsThePhrasesCandidates() async throws {
        let candidates = try await worker.candidates(for: unit(.bunsetsu(clause: "kyouha", index: 0), reading: "きょうは"), readingInClause: 0..<4)
        #expect(candidates.contains(ConversionCandidate("今日は", .japanese)))
        #expect(candidates.contains(ConversionCandidate("強は", .japanese)))
    }

    @Test func endsAPhrasesCandidatesWithItsLettersAsEnglish() async throws {
        let candidates = try await worker.candidates(
            for: unit(.bunsetsu(clause: "kyouhaweare", index: 1), reading: "うぇあれ"),
            readingInClause: 4..<8
        )
        // ↑ from the first candidate reaches the words first
        #expect(candidates.suffix(2) == [ConversionCandidate("weare", .english), ConversionCandidate("we are", .english)])
        #expect(candidates.first?.language == .japanese)
    }

    @Test func offersALoneWordAsEnglishOnce() async throws {
        let candidates = try await worker.candidates(for: unit(.bunsetsu(clause: "sake", index: 0), reading: "さけ"), readingInClause: 0..<2)
        #expect(candidates.filter { $0.language == .english } == [ConversionCandidate("sake", .english)])
    }

    @Test func offersEnglishThatReadsAsRomajiInJapaneseToo() async throws {
        let candidates = try await worker.candidates(for: unit(.english("sake"), reading: "sake"), readingInClause: nil)
        #expect(candidates.first == ConversionCandidate("sake", .english))
        #expect(candidates.contains(ConversionCandidate("酒", .japanese)))
    }

    @Test func offersOtherEnglishOnlyAsTyped() async throws {
        #expect(try await worker.candidates(for: unit(.english("google"), reading: "google"), readingInClause: nil) == [ConversionCandidate("google", .english)])
    }

    @Test func convertsBothPhrasesAgainAfterMovingTheirBorder() async throws {
        var phrases = [Bunsetsu(reading: "きょうはてんきがいい", text: "強は天気がいい")]
        for _ in 0..<6 {
            phrases = try await worker.resized(phrases, at: 0, by: -1)
        }
        #expect(phrases == [Bunsetsu(reading: "きょうは", text: "今日は"), Bunsetsu(reading: "てんきがいい", text: "天気がいい")])
    }

    @Test func leavesPhrasesThatCannotResizeAsTheyAre() async throws {
        let phrases = [Bunsetsu(reading: "きょうは", text: "今日は")]
        #expect(try await worker.resized(phrases, at: 0, by: 1) == phrases)
    }

    @Test func convertsWithTheChoices() async throws {
        var choices = ConversionChoices()
        choices.clauses["kyouhatenkigaii"] = [Bunsetsu(reading: "きょうは", text: "今日は"), Bunsetsu(reading: "てんきがいい", text: "天気がいい")]
        #expect(try await worker.convert("kyouhatenkigaii", style: .touten, choices: choices).text == "今日は天気がいい")
    }
}
