import Testing
@testable import KaedeCore

/// Lines the user actually typed, mixing QWERTY and Ebi, English and Japanese, without spaces
/// at the switches. Expected readings are worked out key by key; typos are kept as typed.
@Suite struct MixedCorpusTests {
    let planner: EnterPlanner

    init() throws {
        planner = EnterPlanner(lexicon: try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists))
    }

    @Test func theIdealSentenceFromTheSpec() {
        let typed = "watashinoiflsgjdhfkf;ahskkkahakk.fmd QWERTY ;afidjgjs Ebi-sand layoutgamazattarieigotokf;skknsna,azajjd,shfjfkkjs;dkkhakksairerukotodesu"
        #expect(planner.plan(Run(typing: typed)) == .convert([
            .romaji("watashinorisoutekinihakonnnakannjide"),
            .verbatim(" QWERTY "),
            .romaji("hairetuto"),
            .verbatim(" Ebi-sand layout"),
            .romaji("gamazattarieigotonihonngogamazattemokitinntohennkannsairerukotodesu"),
        ]))
    }

    @Test func englishWordThenEbiJapanese() {
        let typed = "api;a,amajdfhosglfjdfkafmdlgnamsgoajjdja,dlfjdfigksmdlosghar msg.fhhsgusjs,did/affksmdlosgha"
        #expect(planner.plan(Run(typing: typed)) == .convert([
            .verbatim("api"),
            .romaji("hamadateikyousiteinaidesugadouyattetamesiteirunodesyouka."),
            .verbatim(" "),
            .romaji("doujikkouwotomerebaiinodesyouka"),
        ]))
    }

    @Test func englishWordsInsideEbiJapanese() {
        let typed = "lgg.fjgjghajjd,fighska;akzdmdlosgha;dkkka;dkkhakk;aajshaiakasldigosgkflg/a.gg/gkkkmajss,sjjdf,algrhshsmd;aoa;aifdfnsjskf;skknsqwertyjsebikamsna;ghgzagkf,azajjd,skasigosgkflfjamfldg"
        #expect(planner.plan(Run(typing: typed)) == .convert([
            .romaji("suujitutukattemirukonahanzedesyoukahennnahennkannhaatokaranaoseruyounisubajuubunnndatoomotteimasu.kokodehayaharieigotonihonngo"),
            .verbatim("qwerty"),
            .romaji("to"),
            .verbatim("ebi"),
            .romaji("nadogahukuzaunimazattemonaoruyounisitadiseu"),
        ]))
    }
}
