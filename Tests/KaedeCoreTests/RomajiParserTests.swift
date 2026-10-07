import Testing
@testable import KaedeCore

@Suite struct RomajiParserTests {
    @Test(arguments: ["kyouha", "watashinonamaeha", "hon", "kitte", "konnnichiha", "si", "tsu"])
    func wholeSyllablesAreRomaji(chunk: String) {
        #expect(RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["shi", "si", "chi", "ti", "tsu", "tu", "fu", "hu", "ji", "zi", "sha", "sya", "cho", "tyo", "ja", "jya", "zya", "kyo", "nyu", "ryo"])
    func hepburnAndKunreiSpellingsAreBothRomaji(chunk: String) {
        #expect(RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["kitte", "zasshi", "macchi"])
    func aDoubledConsonantIsSokuon(chunk: String) {
        #expect(RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["kanji", "hon", "konnnaka", "hennkann"])
    func nIsHatsuonBeforeAConsonantOrAtTheEndAndNnAlways(chunk: String) {
        #expect(RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["kyouhag", "kit", "ky"])
    func aSyllableStillBeingTypedIsNotRomaji(chunk: String) {
        #expect(!RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["karaq", "kqara", "jajsd"])
    func lettersNoSyllableTakesAreNotRomaji(chunk: String) {
        #expect(!RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["Tokyo", "kyouHa"])
    func uppercaseLettersAreNotRomaji(chunk: String) {
        #expect(!RomajiParser.isPlainRomaji(chunk))
    }

    @Test(arguments: ["allyou", "xa", "ltu"])
    func smallKanaSpellingsAreNotRomaji(chunk: String) {
        // "llyo" would read as っょ, which ordinary Japanese typing never produces
        #expect(!RomajiParser.isPlainRomaji(chunk))
    }

    @Test func aHyphenAfterASyllableReadsAsALongVowel() {
        // ko-hi- is how コーヒー is typed
        #expect(RomajiParser.isPlainRomaji("ra-men"))
        #expect(RomajiParser.isPlainRomaji("ko-hi-"))
        #expect(!RomajiParser.isPlainRomaji("-ko"))
    }

    @Test func nothingIsNotRomaji() {
        #expect(!RomajiParser.isPlainRomaji(""))
    }
}
