import Testing
@testable import KaedeCore

/// A small lexicon, so the cases do not hang on what en10k happens to hold. Its order is the rank.
private let lexicon = EnglishLexicon(wordList: """
    the
    is
    a
    to
    no
    he
    this
    all
    you
    need
    love
    there
    site
    google
    python
    bug
    push
    commit
    deploy
    sit
    school
    tokyo
    """)

@Suite struct WordCoverTests {
    let cover = WordCover(lexicon: lexicon)

    @Test func findsAnEnglishWordBetweenRomaji() {
        #expect(cover.cover("kyouhagoogledekensaku") == [.romaji("kyouha"), .english(["google"]), .romaji("dekensaku")])
    }

    @Test func splitsEnglishTypedWithoutSpaces() {
        #expect(cover.cover("thisistheneed") == [.english(["this", "is", "the", "need"])])
    }

    @Test func leavesReadableLettersAtTheEdgeToRomaji() {
        // "a" and "to" would read as English too, but next to romaji they stay romaji
        #expect(cover.cover("sikasinoatoallyouneedislove") == [.romaji("sikasinoato"), .english(["all", "you", "need", "is", "love"])])
    }

    @Test func takesAParticleAfterOneEnglishWordAsRomaji() {
        #expect(cover.cover("pythonnobug") == [.english(["python"]), .romaji("no"), .english(["bug"])])
        #expect(cover.cover("commitsitepushsite") == [.english(["commit"]), .romaji("site"), .english(["push"]), .romaji("site")])
    }

    @Test func takesAParticleAfterTwoEnglishWordsAsEnglish() {
        #expect(cover.cover("thereisnobug") == [.english(["there", "is", "no", "bug"])])
    }

    @Test func endsNoEnglishWithAOrI() {
        #expect(cover.cover("deploysita") == [.english(["deploy"]), .romaji("sita")])
    }

    @Test func readsTheParticleAfterAnEnglishWordAsRomaji() {
        #expect(cover.cover("kameramotteschoolheiku") == [.romaji("kameramotte"), .english(["school"]), .romaji("heiku")])
    }

    @Test func keepsTheCaseOfEnglishWords() {
        #expect(cover.cover("Tokyonisumu") == [.english(["Tokyo"]), .romaji("nisumu")])
    }

    @Test func coversNothingWithLettersNoWordOrSyllableTakes() {
        #expect(cover.cover("kubernetes") == nil)
    }
}

@Suite struct UnknownStemTests {
    let cover = WordCover(lexicon: lexicon)

    @Test func splitsAnUnknownWordFromTheParticleAfterIt() {
        #expect(cover.unknownStem("grokga") == [.english(["grok"]), .romaji("ga")])
        #expect(cover.unknownStem("kubernetesno") == [.english(["kubernetes"]), .romaji("no")])
    }

    @Test func splitsNothingWithoutAParticle() {
        #expect(cover.unknownStem("kubernetes") == nil)
        // The readable end starts at "au", so where the name ends is a guess
        #expect(cover.unknownStem("claudetohanashita") == nil)
    }
}

@Suite struct WordCoverWithBundledWordsTests {
    let cover = WordCover(lexicon: try! EnglishLexicon(contentsOfFiles: bundledWordLists))

    @Test func prefersCommonWords() {
        // en10k holds "isa" too, but "is a" is far more common
        #expect(cover.cover("thisisapen") == [.english(["this", "is", "a", "pen"])])
        #expect(cover.cover("allyouneedisattention") == [.english(["all", "you", "need", "is", "attention"])])
    }

    @Test func keepsRomajiOutOfEnglish() {
        #expect(cover.cover("sikasinoatoallyouneedislove") == [.romaji("sikasinoato"), .english(["all", "you", "need", "is", "love"])])
        // en10k holds "sit" too
        #expect(cover.cover("pushsita") == [.english(["push"]), .romaji("sita")])
    }
}
