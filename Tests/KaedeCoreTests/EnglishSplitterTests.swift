import Testing
@testable import KaedeCore

@Suite struct EnglishSplitterTests {
    let splitter: EnglishSplitter

    init() throws {
        // Common words only: with every dictionary word, "need is" loses to "nee dis"
        splitter = EnglishSplitter(commonWords: try EnglishLexicon(contentsOfFiles: bundledWordLists))
    }

    @Test func splitsRunTogetherEnglishIntoTheFewestCommonWords() {
        #expect(splitter.split("allyouneedisattention") == ["all", "you", "need", "is", "attention"])
        #expect(splitter.split("thankyou") == ["thank", "you"])
    }

    @Test func keepsTheLettersAsTyped() {
        #expect(splitter.split("ThankYou") == ["Thank", "You"])
    }

    @Test(arguments: ["keyboard", "xyzq"])
    func doesNotSplitOneWordOrUnknownLetters(letters: String) {
        #expect(splitter.split(letters) == nil)
    }

    @Test func keepsAnUncommonPartAsItsOwnWord() {
        // "expl" is a word still being typed; the rest are common words
        #expect(splitter.split("explanationisallyouneedbuttheexpl") == [
            "explanation", "is", "all", "you", "need", "but", "the", "expl",
        ])
    }

    @Test func doesNotSplitWhenCommonWordsCoverTooLittle() {
        // "api" then Ebi-fingered kone: mostly not English
        #expect(splitter.split("apihskd") == nil)
    }
}
