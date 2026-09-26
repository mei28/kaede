import Testing
@testable import KaedeCore

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

    @Test func loadsTheSystemWordList() throws {
        let lexicon = try EnglishLexicon(contentsOfFile: "/usr/share/dict/words")
        #expect(lexicon.contains("and"))
        #expect(!lexicon.contains("tatoeba"))
    }

    @Test func failsToLoadAMissingFile() {
        #expect(throws: (any Error).self) {
            try EnglishLexicon(contentsOfFile: "/nonexistent/words")
        }
    }
}
