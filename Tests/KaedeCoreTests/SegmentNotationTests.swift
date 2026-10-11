import Testing
@testable import KaedeCore

@Suite struct SegmentNotationTests {
    private func segment(_ content: Segment.Content) -> Segment {
        Segment(content: content, spaceBefore: false)
    }

    @Test func writesEachSegmentByItsKind() {
        let segments = [
            segment(.romaji("kyouha")), segment(.english("google")), segment(.romaji("dekensaku")),
            segment(.punctuation(".", .japanese)), segment(.digits("10")), segment(.mark("(")),
            segment(.japaneseText("今日は")), segment(.punctuation(",", .english)),
        ]
        #expect(SegmentNotation.notation(of: segments) == "ja(kyouha) en(google) ja(dekensaku) 。 num(10) mark(() text(今日は) ,")
    }

    @Test func marksWhatWasReadThroughTheLayout() {
        let clause = Clause([
            Spelling(qwerty: "watashino"),
            Spelling(text: "risoutekiniha", typed: "iflsgjdhfkf;a", fingering: .layout),
        ])
        let segments = [segment(.romaji(clause)), segment(.english(Spelling(text: "world", typed: "usiwm", fingering: .layout)))]
        #expect(SegmentNotation.notation(of: segments) == "ja(watashino + L:risoutekiniha) en/L(world)")
    }
}
