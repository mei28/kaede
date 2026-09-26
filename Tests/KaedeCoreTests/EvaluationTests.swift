import Testing
@testable import KaedeCore

@Suite struct EvaluationTests {
    @Test func parsesTabSeparatedPairsSkippingBlankAndCommentLines() throws {
        let tsv = "# typed\tintended\njajsd/a\t例えば\n\nhskkkahakk.fmd\tこんな感じで\n"
        #expect(try Corpus.parse(tsv) == [
            CorpusEntry(typed: "jajsd/a", intended: "例えば"),
            CorpusEntry(typed: "hskkkahakk.fmd", intended: "こんな感じで"),
        ])
    }

    @Test func failsOnALineWithoutExactlyOneTab() {
        #expect(throws: Corpus.ParseError.malformedLine(number: 2)) {
            try Corpus.parse("jajsd/a\t例えば\nhskkkahakk.fmd\n")
        }
    }

    @Test(arguments: [
        ("変換", "変換", 0),
        ("返還", "変換", 2),
        ("", "例えば", 3),
        ("こんな感じ", "こんな感じで", 1),
        ("kitten", "sitting", 3),
    ])
    func editDistanceCountsCharacterEdits(output: String, intended: String, distance: Int) {
        #expect(Scoring.editDistance(output, intended) == distance)
    }

    @Test func summarizesExactMatchesCharacterErrorsAndLatency() {
        let results = [
            EvaluationResult(intended: "変換", output: "変換", duration: .milliseconds(30)),
            EvaluationResult(intended: "例えば", output: "例えば", duration: .milliseconds(10)),
            EvaluationResult(intended: "こんな感じで", output: "こんな感じ", duration: .milliseconds(50)),
        ]
        let summary = Scoring.summary(of: results)
        #expect(summary.exactMatches == 2)
        #expect(summary.total == 3)
        // 1 edit over 2 + 3 + 6 intended characters
        #expect(summary.characterErrorRate == 1.0 / 11.0)
        #expect(summary.medianLatency == .milliseconds(30))
        #expect(summary.maxLatency == .milliseconds(50))
    }
}
