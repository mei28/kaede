import Testing
@testable import KaedeCore

@Suite struct RomajiParserTests {
    @Test func karaIsRomaji() {
        #expect(RomajiParser.isPlainRomajiPrefix("kara"))
    }

    @Test func lettersNoSyllableCanContinueAreNotRomaji() {
        #expect(!RomajiParser.isPlainRomajiPrefix("karaq"))
        #expect(!RomajiParser.isPlainRomajiPrefix("kqara"))
    }

    @Test func hepburnAndKunreiSpellingsAreBothRomaji() {
        for chunk in ["shi", "si", "chi", "ti", "tsu", "tu", "fu", "hu", "ji", "zi", "sha", "sya", "cho", "tyo", "ja", "jya", "zya", "kyo", "nyu", "ryo"] {
            #expect(RomajiParser.isPlainRomajiPrefix(chunk), "\(chunk)")
        }
    }

    @Test func aDoubledConsonantIsSokuon() {
        #expect(RomajiParser.isPlainRomajiPrefix("kitte"))
        #expect(RomajiParser.isPlainRomajiPrefix("zasshi"))
        #expect(RomajiParser.isPlainRomajiPrefix("macchi"))
    }

    @Test func nIsHatsuonBeforeAConsonantOrAtTheEndAndNnAlways() {
        #expect(RomajiParser.isPlainRomajiPrefix("kanji"))
        #expect(RomajiParser.isPlainRomajiPrefix("hon"))
        #expect(RomajiParser.isPlainRomajiPrefix("konnnaka"))
        #expect(RomajiParser.isPlainRomajiPrefix("hennkann"))
    }

    @Test func commaAndPeriodAreReadableAsJapanesePunctuation() {
        #expect(RomajiParser.isPlainRomajiPrefix("hai,iie."))
    }

    @Test func uppercaseLettersAreNotRomaji() {
        #expect(!RomajiParser.isPlainRomajiPrefix("Kara"))
        #expect(!RomajiParser.isPlainRomajiPrefix("KKara"))
    }

    @Test func symbolsFromEbiPositionsAreNotRomaji() {
        // Ebi puts , . ; / on the QWERTY e r t b positions; only , and . read as punctuation
        #expect(!RomajiParser.isPlainRomajiPrefix(";a"))
        #expect(!RomajiParser.isPlainRomajiPrefix("a/"))
    }

    @Test func aWordOnItsWayToRomajiIsAPlainRomajiPrefix() {
        // Whole syllables, then perhaps one still being typed
        for chunk in ["", "tatoe", "tatoeb", "ky", "sh", "ts", "kit", "kitt", "kan", "hai,"] {
            #expect(RomajiParser.isPlainRomajiPrefix(chunk), "\(chunk)")
        }
    }

    @Test func lettersNoSyllableCanContinueAreNoPlainRomajiPrefix() {
        for chunk in ["jajsd", "q", "js", "Ta", ";a"] {
            #expect(!RomajiParser.isPlainRomajiPrefix(chunk), "\(chunk)")
        }
    }

    @Test func smallKanaSpellingsAreNoPlainRomajiPrefix() {
        #expect(!RomajiParser.isPlainRomajiPrefix("xa"))
        #expect(!RomajiParser.isPlainRomajiPrefix("lt"))
        // "llyo" would read as っょ, which ordinary Japanese typing never produces
        #expect(!RomajiParser.isPlainRomajiPrefix("allyouneedisattention"))
    }

    @Test func aHyphenAfterASyllableReadsAsALongVowel() {
        // ko-hi- is how コーヒー is typed
        #expect(RomajiParser.isPlainRomajiPrefix("ko-hi-"))
        #expect(!RomajiParser.isPlainRomajiPrefix("-ko"))
        #expect(!RomajiParser.isPlainRomajiPrefix("k-"))
    }
}
