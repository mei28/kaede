import Testing
@testable import KaedeCore

/// A small lexicon, so the cases do not hang on what en10k happens to hold.
private let lexicon = EnglishLexicon(wordList: """
    the
    is
    a
    to
    no
    go
    he
    i
    this
    all
    you
    need
    love
    there
    are
    want
    park
    how
    use
    sake
    google
    python
    bug
    push
    school
    tokyo
    error
    api
    hello
    world
    pen
    """)

private func romaji(_ text: String, space: Bool = false) -> Segment {
    Segment(content: .romaji(Clause([Spelling(qwerty: text)])), spaceBefore: space)
}

private func english(_ text: String, space: Bool = false) -> Segment {
    Segment(content: .english(Spelling(text: text, typed: text.filter { $0 != " " }, fingering: .qwerty)), spaceBefore: space)
}

private func punctuation(_ character: Character, _ language: Language) -> Segment {
    Segment(content: .punctuation(character, language), spaceBefore: false)
}

@Suite struct LineSegmenterTests {
    let segmenter = LineSegmenter(lexicon: lexicon)

    private func segments(_ line: String) -> [Segment] {
        segmenter.segments(of: line[...])
    }

    @Test func findsEnglishInsideRomaji() {
        #expect(segments("kyouhagoogledekensaku") == [romaji("kyouha"), english("google"), romaji("dekensaku")])
    }

    @Test func joinsRomajiAcrossSpacesIntoOneClause() {
        #expect(segments("kyouha tenkiga ii") == [romaji("kyouhatenkigaii")])
    }

    @Test func splitsEnglishTypedWithoutSpaces() {
        #expect(segments("thisisapen.") == [english("this is a pen"), punctuation(".", .english)])
    }

    @Test func givesPunctuationTheLanguageOfTheWordBefore() {
        #expect(segments("kore,sore.") == [romaji("kore"), punctuation(",", .japanese), romaji("sore"), punctuation(".", .japanese)])
        #expect(segments("desu.kyouha") == [romaji("desu"), punctuation(".", .japanese), romaji("kyouha")])
        #expect(segments("hello, world.") == [english("hello"), punctuation(",", .english), english("world", space: true), punctuation(".", .english)])
    }

    @Test func takesASpacedNoAsJapaneseUnlessTwoEnglishWordsComeBefore() {
        #expect(segments("python no bug") == [english("python"), romaji("no", space: true), english("bug", space: true)])
        #expect(segments("there is no bug") == [english("there"), english("is", space: true), english("no", space: true), english("bug", space: true)])
    }

    @Test func movesAnEnglishWordOutOfRomajiBeforeAParticle() {
        #expect(segments("apinoerror") == [english("api"), romaji("no"), english("error")])
        #expect(segments("apino error") == [english("api"), romaji("no"), english("error", space: true)])
    }

    @Test func decidesWordsOfBothLanguagesByTheWordsAround() {
        #expect(segments("kinouno are") == [romaji("kinounoare")])
        #expect(segments("sake") == [romaji("sake")])
        #expect(segments("how to use") == [english("how"), english("to", space: true), english("use", space: true)])
        #expect(segments("i want to go to the park") == [
            english("i"), english("want", space: true), english("to", space: true), english("go", space: true),
            english("to", space: true), english("the", space: true), english("park", space: true),
        ])
    }

    @Test func keepsACapitalisedWordEnglish() {
        #expect(segments("Kaede") == [english("Kaede")])
        #expect(segments("Tokyonisumu") == [english("Tokyo"), romaji("nisumu")])
    }

    @Test func keepsAnUnknownWordAsTyped() {
        #expect(segments("kubernetes") == [english("kubernetes")])
        #expect(segments("grokga") == [english("grok"), romaji("ga")])
    }

    @Test func putsDigitsNextToRomajiIntoTheClause() {
        #expect(segments("10ji") == [romaji("10ji")])
        #expect(segments("kyouha 3ji") == [romaji("kyouha3ji")])
        #expect(segments("python 3") == [english("python"), Segment(content: .digits("3"), spaceBefore: true)])
    }

    @Test func readsHyphenatedWords() {
        #expect(segments("ra-men") == [romaji("ra-men")])
        #expect(segments("e-mail") == [english("e-mail")])
    }

    @Test func keepsTextTypedWithAnInputMethod() {
        #expect(segments("今日は google") == [Segment(content: .japaneseText("今日は"), spaceBefore: false), english("google", space: true)])
    }
}

/// What the segmenter makes of typed text with dots, hyphens, slashes and marks today, kept while
/// the tokenizer changes underneath.
@Suite struct LineSegmenterCharacterizationTests {
    let segmenter = LineSegmenter(lexicon: lexicon)

    @Test(arguments: [
        ("main.swift", "en(main.swift)"),
        ("node.js", "en(node.js)"),
        ("desu.kyouha", "ja(desu) 。 ja(kyouha)"),
        ("3-4", "en(3-4)"),
        ("kore;", "ja(kore) mark(;)"),
        ("\"quote\":", "mark(\") en(quote) mark(\") mark(:)"),
        ("1,000yen", "ja(1,000yen)"),
        ("e-mail", "en(e-mail)"),
        ("src/kaede", "en(src/kaede)"),
        ("x64,arm64", "en(x) num(64) , en(arm) num(64)"),
        ("kore,sore.", "ja(kore) 、 ja(sore) 。"),
        ("Hello.World", "en(Hello.World)"),
        ("hai, iie", "ja(hai) 、 ja(iie)"),
    ])
    func keepsWhatItMakesOfTypedText(typed: String, expected: String) {
        #expect(SegmentNotation.notation(of: segmenter.segments(of: typed[...])) == expected)
    }
}
