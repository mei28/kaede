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
        #expect(lexicon.containsWord(startingWith: "cat"))
    }

    @Test func rejectsAnUnlistedWord() {
        let lexicon = EnglishLexicon(wordList: "apple\ncat\n")
        #expect(!lexicon.containsWord(startingWith: "jajsd"))
    }

    @Test func ignoresCaseOnBothSides() {
        let lexicon = EnglishLexicon(wordList: "the\nTokyo\n")
        #expect(lexicon.containsWord(startingWith: "The"))
        #expect(lexicon.containsWord(startingWith: "tokyo"))
    }

    @Test func loadsTheSystemWordListAndTheBundledLists() throws {
        let lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists)
        #expect(lexicon.containsWord(startingWith: "and"))
        #expect(lexicon.containsWord(startingWith: "has"))  // only in en10k.txt
        #expect(lexicon.containsWord(startingWith: "qwerty"))  // only in extra-words.txt
        #expect(!lexicon.containsWord(startingWith: "tatoeba"))
    }

    @Test func failsToLoadAMissingFile() {
        #expect(throws: (any Error).self) {
            try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words", "/nonexistent/words"])
        }
    }

    @Test func knowsWordsFromEveryList() {
        let lexicon = EnglishLexicon(wordLists: ["cat\ndog\n", "has\nqwerty\n"])
        #expect(lexicon.containsWord(startingWith: "cat"))
        #expect(lexicon.containsWord(startingWith: "has"))
        #expect(!lexicon.containsWord(startingWith: "jajsd"))
    }

    @Test func countsWordsOfTwoLettersOrFewerOnlyWhenAllowlisted() {
        // Word lists carry romaji-like fragments such as "ha" and "ko" that would split Japanese
        let lexicon = EnglishLexicon(wordList: "a\nI\nto\nha\nko\nx\n")
        #expect(lexicon.containsWord(startingWith: "a"))
        #expect(lexicon.containsWord(startingWith: "I"))
        #expect(lexicon.containsWord(startingWith: "to"))
        #expect(!lexicon.containsWord(startingWith: "ha"))
        #expect(!lexicon.containsWord(startingWith: "ko"))
        #expect(!lexicon.containsWord(startingWith: "x"))
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

@Suite struct EnglishLexiconRankTests {
    @Test func knowsAWholeWordInAnyCase() {
        let lexicon = EnglishLexicon(wordList: "the\nTokyo\n")
        #expect(lexicon.contains("the"))
        #expect(lexicon.contains("The"))
        #expect(lexicon.contains("tokyo"))
        #expect(!lexicon.contains("th"))
    }

    @Test func ranksWordsInTheOrderOfTheirList() {
        let lexicon = EnglishLexicon(wordList: "the\nof\nand\n")
        #expect(lexicon.rank(of: "the") == 1)
        #expect(lexicon.rank(of: "And") == 3)
        #expect(lexicon.rank(of: "cat") == nil)
    }

    @Test func takesTheBestRankAcrossLists() {
        // The short list of the user's own words ranks them with the most common words
        let lexicon = EnglishLexicon(wordLists: ["the\nof\ngithub\n", "github\n"])
        #expect(lexicon.rank(of: "github") == 1)
    }

    @Test func countsItsWords() {
        #expect(EnglishLexicon(wordLists: ["the\nof\n", "of\ngithub\n"]).count == 3)
    }
}
