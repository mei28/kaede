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

    @Test func loadsTheBundledLists() throws {
        let lexicon = try EnglishLexicon(contentsOfFiles: bundledWordLists)
        #expect(lexicon.contains("and"))
        #expect(lexicon.contains("has"))  // only in en10k.txt
        #expect(lexicon.contains("qwerty"))  // only in extra-words.txt
        #expect(!lexicon.contains("tatoeba"))
    }

    @Test func failsToLoadAMissingFile() {
        #expect(throws: (any Error).self) {
            try EnglishLexicon(contentsOfFiles: bundledWordLists + ["/nonexistent/words"])
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
