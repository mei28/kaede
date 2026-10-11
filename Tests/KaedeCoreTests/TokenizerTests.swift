import Testing
@testable import KaedeCore

@Suite struct TokenizerTests {
    private func tokens(_ line: String) -> [Token] {
        Tokenizer.tokens(of: line[...]).map(\.token)
    }

    @Test func splitsAtSpacesAndRemembersThem() {
        #expect(Tokenizer.tokens(of: "kyouha  google"[...]) == [
            TypedToken(token: .keys("kyouha"), spaceBefore: false),
            TypedToken(token: .keys("google"), spaceBefore: true),
        ])
    }

    @Test func takesTabsAndIdeographicSpacesAsSpaces() {
        #expect(tokens("a\tb\u{3000}c") == [.keys("a"), .keys("b"), .keys("c")])
    }

    @Test func keepsTextTypedWithAnInputMethod() {
        #expect(tokens("今日は google") == [.verbatim("今日は", .japanese), .keys("google")])
        #expect(tokens("café") == [.verbatim("café", .english)])
    }

    @Test func passesLettersAndTheFourSymbolKeysOnAsOneRun() {
        // A layout may put letters on , . ; / (Ebi's tatoeba arrives as jajsd/a)
        #expect(tokens("jajsd/a") == [.keys("jajsd/a")])
        #expect(tokens("kore,sore") == [.keys("kore,sore")])
        #expect(tokens("main.swift") == [.keys("main.swift")])
    }

    @Test func cutsPunctuationOffTheEnd() {
        #expect(tokens("kore,sore.") == [.keys("kore,sore"), .punctuation(".")])
        #expect(tokens("Hello!") == [.keys("Hello"), .punctuation("!")])
        #expect(tokens("hontou?") == [.keys("hontou"), .punctuation("?")])
    }

    @Test func keepsNumbersWhole() {
        #expect(tokens("1.5") == [.digits("1.5")])
        #expect(tokens("1,000yen") == [.digits("1,000"), .keys("yen")])
    }

    @Test func keepsPathsAddressesAndContractionsAsTyped() {
        #expect(tokens("~/src/kaede") == [.verbatim("~/src/kaede", .english)])
        #expect(tokens("mei@example.com") == [.verbatim("mei@example.com", .english)])
        #expect(tokens("don't") == [.verbatim("don't", .english)])
        #expect(tokens("snake_case") == [.verbatim("snake_case", .english)])
    }

    @Test func cutsBracketsAndQuotesOffWords() {
        #expect(tokens("(kakko)") == [.mark("("), .keys("kakko"), .mark(")")])
        #expect(tokens("\"quote\":") == [.mark("\""), .keys("quote"), .mark("\""), .mark(":")])
    }

    @Test func separatesKeysFromDigits() {
        #expect(tokens("10ji") == [.digits("10"), .keys("ji")])
        #expect(tokens("iPhone15") == [.keys("iPhone"), .digits("15")])
    }

    @Test func keepsAHyphenAfterALetterInTheRun() {
        #expect(tokens("ra-men") == [.keys("ra-men")])
        #expect(tokens("ko-hi-") == [.keys("ko-hi-")])
        #expect(tokens("e-mail") == [.keys("e-mail")])
        #expect(tokens("3-4") == [.verbatim("3-4", .english)])
    }

    @Test func findsNothingInBlankLines() {
        #expect(tokens("").isEmpty)
        #expect(tokens("   ").isEmpty)
    }
}

@Suite struct QwertyKeyRunTests {
    @Test func cutsCommasAndPeriodsBetweenLetters() {
        #expect(KeyRun.qwertyTokens("kore,sore") == [.letters("kore"), .punctuation(","), .letters("sore")])
        #expect(KeyRun.qwertyTokens(",arm") == [.punctuation(","), .letters("arm")])
    }

    @Test func cutsAPeriodBetweenRomajiOnly() {
        #expect(KeyRun.qwertyTokens("desu.kyouha") == [.letters("desu"), .punctuation("."), .letters("kyouha")])
        #expect(KeyRun.qwertyTokens("main.swift") == [.verbatim("main.swift", .english)])
        #expect(KeyRun.qwertyTokens("node.js") == [.verbatim("node.js", .english)])
    }

    @Test func keepsARunWithSemicolonsOrSlashesAsTyped() {
        #expect(KeyRun.qwertyTokens("src/kaede") == [.verbatim("src/kaede", .english)])
        #expect(KeyRun.qwertyTokens("a;b") == [.verbatim("a;b", .english)])
    }

    @Test func keepsHyphensInTheLetters() {
        #expect(KeyRun.qwertyTokens("ra-men") == [.letters("ra-men")])
    }
}
