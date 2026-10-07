import Testing
@testable import KaedeCore

@Suite struct TokenizerTests {
    private func tokens(_ line: String) -> [Token] {
        Tokenizer.tokens(of: line[...]).map(\.token)
    }

    @Test func splitsAtSpacesAndRemembersThem() {
        #expect(Tokenizer.tokens(of: "kyouha  google"[...]) == [
            TypedToken(token: .letters("kyouha"), spaceBefore: false),
            TypedToken(token: .letters("google"), spaceBefore: true),
        ])
    }

    @Test func takesTabsAndIdeographicSpacesAsSpaces() {
        #expect(tokens("a\tb\u{3000}c") == [.letters("a"), .letters("b"), .letters("c")])
    }

    @Test func keepsTextTypedWithAnInputMethod() {
        #expect(tokens("今日は google") == [.verbatim("今日は", .japanese), .letters("google")])
        #expect(tokens("café") == [.verbatim("café", .english)])
    }

    @Test func cutsPunctuationOffWords() {
        #expect(tokens("kore,sore.") == [.letters("kore"), .punctuation(","), .letters("sore"), .punctuation(".")])
        #expect(tokens("Hello!") == [.letters("Hello"), .punctuation("!")])
        #expect(tokens("hontou?") == [.letters("hontou"), .punctuation("?")])
    }

    @Test func cutsAPeriodBetweenRomajiOnly() {
        #expect(tokens("desu.kyouha") == [.letters("desu"), .punctuation("."), .letters("kyouha")])
        #expect(tokens("main.swift") == [.verbatim("main.swift", .english)])
        #expect(tokens("node.js") == [.verbatim("node.js", .english)])
    }

    @Test func keepsNumbersWhole() {
        #expect(tokens("1.5") == [.digits("1.5")])
        #expect(tokens("1,000yen") == [.digits("1,000"), .letters("yen")])
    }

    @Test func keepsPathsAddressesAndContractionsAsTyped() {
        #expect(tokens("~/src/kaede") == [.verbatim("~/src/kaede", .english)])
        #expect(tokens("mei@example.com") == [.verbatim("mei@example.com", .english)])
        #expect(tokens("don't") == [.verbatim("don't", .english)])
        #expect(tokens("snake_case") == [.verbatim("snake_case", .english)])
    }

    @Test func cutsBracketsAndQuotesOffWords() {
        #expect(tokens("(kakko)") == [.mark("("), .letters("kakko"), .mark(")")])
        #expect(tokens("\"quote\":") == [.mark("\""), .letters("quote"), .mark("\""), .mark(":")])
    }

    @Test func separatesLettersFromDigits() {
        #expect(tokens("10ji") == [.digits("10"), .letters("ji")])
        #expect(tokens("iPhone15") == [.letters("iPhone"), .digits("15")])
    }

    @Test func keepsAHyphenAfterALetterInTheWord() {
        #expect(tokens("ra-men") == [.letters("ra-men")])
        #expect(tokens("ko-hi-") == [.letters("ko-hi-")])
        #expect(tokens("e-mail") == [.letters("e-mail")])
        #expect(tokens("3-4") == [.verbatim("3-4", .english)])
    }

    @Test func findsNothingInBlankLines() {
        #expect(tokens("").isEmpty)
        #expect(tokens("   ").isEmpty)
    }
}
