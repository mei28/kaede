import Testing
@testable import KaedeCore

@Suite struct SegmenterTests {
    let segmenter = Segmenter(lexicon: EnglishLexicon(wordList: ""))

    func token(_ typed: String) -> Token {
        let run = Run(typing: typed)
        return Token(qwerty: run.reading(in: .qwerty), ebi: run.reading(in: .ebi))
    }

    @Test func topSegmentationsStartWithTheBestAndIncludeTheRunnerUpOfATie() {
        let top = segmenter.topSegmentations(of: token("watashinoiflsgjdhfkf;a"), count: 3)
        #expect(top.first == segmenter.segments(of: token("watashinoiflsgjdhfkf;a")))
        #expect(top.contains([
            Segment(kind: .qwertyJapanese, text: "watashinoi"),
            Segment(kind: .ebiJapanese, text: "isoutekiniha"),
        ]))
        #expect(top.count == 3)
        #expect(Set(top.map { $0.map(\.text).joined(separator: "|") }).count == 3)  // no duplicates
    }
}
