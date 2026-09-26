import Testing
@testable import KaedeCore

@Suite struct RomajiParserTests {
    @Test func karaIsRomaji() {
        #expect(RomajiParser.isRomaji("kara"))
    }

    @Test func aChunkThatStopsBeingRomajiMidwayIsNotRomaji() {
        #expect(!RomajiParser.isRomaji("karaq"))
        #expect(!RomajiParser.isRomaji("kqara"))
    }

    @Test func hepburnAndKunreiSpellingsAreBothRomaji() {
        for chunk in ["shi", "si", "chi", "ti", "tsu", "tu", "fu", "hu", "ji", "zi", "sha", "sya", "cho", "tyo", "ja", "jya", "zya", "kyo", "nyu", "ryo"] {
            #expect(RomajiParser.isRomaji(chunk), "\(chunk)")
        }
    }

    @Test func aDoubledConsonantIsSokuon() {
        #expect(RomajiParser.isRomaji("kitte"))
        #expect(RomajiParser.isRomaji("zasshi"))
        #expect(RomajiParser.isRomaji("macchi"))
        #expect(!RomajiParser.isRomaji("kit"))
        #expect(!RomajiParser.isRomaji("kitt"))
    }

    @Test func nIsHatsuonBeforeAConsonantOrAtTheEndAndNnAlways() {
        #expect(RomajiParser.isRomaji("kanji"))
        #expect(RomajiParser.isRomaji("hon"))
        #expect(RomajiParser.isRomaji("konnnaka"))
        #expect(RomajiParser.isRomaji("hennkann"))
    }

    @Test func commaAndPeriodAreReadableAsJapanesePunctuation() {
        #expect(RomajiParser.isRomaji("hai,iie."))
    }

    @Test func uppercaseLettersAreNotRomaji() {
        #expect(!RomajiParser.isRomaji("Kara"))
        #expect(!RomajiParser.isRomaji("KKara"))
    }

    @Test func symbolsFromEbiPositionsAreNotRomaji() {
        // Ebi puts , . ; / on the QWERTY e r t b positions; only , and . read as punctuation
        #expect(!RomajiParser.isRomaji(";a"))
        #expect(!RomajiParser.isRomaji("a/"))
    }

    @Test func smallKanaAreRomaji() {
        for chunk in ["xa", "li", "xtu", "ltu", "xya", "lyo", "fixe"] {
            #expect(RomajiParser.isRomaji(chunk), "\(chunk)")
        }
    }

    @Test func plainRomajiLeavesOutSmallKanaSpellings() {
        // "llyo" reads as っょ, which ordinary Japanese typing never produces
        #expect(RomajiParser.isRomaji("allyouneedisattention"))
        #expect(!RomajiParser.isPlainRomaji("allyouneedisattention"))
        #expect(RomajiParser.isPlainRomaji("ashita"))
        #expect(RomajiParser.isPlainRomaji("hai,iie."))
    }
}
