import Foundation
import Testing
@testable import KaedeCore

/// The word lists in the repository's Resources/, which `just bundle` copies into the app.
let bundledWordLists = ["en10k.txt", "extra-words.txt"].map { name in
    URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Resources/\(name)").path(percentEncoded: false)
}

@Suite struct EnglishLexiconTests {
    @Test func knowsAListedWord() {
        let lexicon = EnglishLexicon(wordList: "apple\ncat\ndog\n")
        #expect(lexicon.contains("cat"))
    }

    @Test func rejectsAnUnlistedWord() {
        let lexicon = EnglishLexicon(wordList: "apple\ncat\n")
        #expect(!lexicon.contains("jajsd"))
    }

    @Test func ignoresCaseOnBothSides() {
        let lexicon = EnglishLexicon(wordList: "the\nTokyo\n")
        #expect(lexicon.contains("The"))
        #expect(lexicon.contains("tokyo"))
    }

    @Test func loadsTheSystemWordListAndTheBundledLists() throws {
        let lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists)
        #expect(lexicon.contains("and"))
        #expect(lexicon.contains("has"))  // only in en10k.txt
        #expect(lexicon.contains("qwerty"))  // only in extra-words.txt
        #expect(!lexicon.contains("tatoeba"))
    }

    @Test func failsToLoadAMissingFile() {
        #expect(throws: (any Error).self) {
            try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words", "/nonexistent/words"])
        }
    }

    @Test func knowsWordsFromEveryList() {
        let lexicon = EnglishLexicon(wordLists: ["cat\ndog\n", "has\nqwerty\n"])
        #expect(lexicon.contains("cat"))
        #expect(lexicon.contains("has"))
        #expect(!lexicon.contains("jajsd"))
    }

    @Test func countsWordsOfTwoLettersOrFewerOnlyWhenAllowlisted() {
        // Word lists carry romaji-like fragments such as "ha" and "ko" that would split Japanese
        let lexicon = EnglishLexicon(wordList: "a\nI\nto\nha\nko\nx\n")
        #expect(lexicon.contains("a"))
        #expect(lexicon.contains("I"))
        #expect(lexicon.contains("to"))
        #expect(!lexicon.contains("ha"))
        #expect(!lexicon.contains("ko"))
        #expect(!lexicon.contains("x"))
    }

    @Test func findsWordsThatStartWithTypedLetters() {
        let lexicon = EnglishLexicon(wordList: "the\nthink\nwater\n")
        #expect(lexicon.containsWord(startingWith: "thi"))
        #expect(lexicon.containsWord(startingWith: "THI"))
        #expect(lexicon.containsWord(startingWith: "think"))
        #expect(!lexicon.containsWord(startingWith: "thinks"))
        #expect(!lexicon.containsWord(startingWith: "jajsd"))
    }

    @Test func startsOnlyWordsItCounts() {
        // "ha" is a fragment the lexicon drops, so nothing starts with it here
        let lexicon = EnglishLexicon(wordList: "ha\n")
        #expect(!lexicon.containsWord(startingWith: "ha"))
    }
}
