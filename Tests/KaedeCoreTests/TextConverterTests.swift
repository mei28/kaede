import Testing
@testable import KaedeCore

private let lexicon = EnglishLexicon(wordList: """
    this
    is
    a
    pen
    python
    bug
    no
    push
    commit
    """)

private let kanji: [String: String] = [
    "kyouha": "今日は",
    "kyouhatenkigaii": "今日は天気がいい",
]

@Suite struct TextConverterTests {
    let converter = TextConverter(lexicon: lexicon)

    private func convert(_ text: String) -> String {
        converter.convert(text, style: .touten) { clause in
            guard let converted = kanji[clause] else {
                Issue.record("asked to convert \(clause)")
                return []
            }
            return [Bunsetsu(reading: clause, text: converted)]
        }
    }

    @Test func convertsEachLineAndKeepsTheLineBreaks() {
        #expect(convert("kyouha\nthisisapen.") == "今日は\nthis is a pen.")
        #expect(convert("kyouha\r\n\r\nkyouha") == "今日は\r\n\r\n今日は")
    }

    @Test func dropsSpacesAroundALine() {
        #expect(convert("  kyouha tenkiga ii  ") == "今日は天気がいい")
    }

    @Test func writesALoneParticleWithoutTheConverter() {
        // On its own azooKey may well write の as 野
        #expect(convert("python no bug") == "python の bug")
        #expect(convert("pythonnobug") == "python の bug")
    }

    @Test func writesALoneVerbEndingWithoutTheConverter() {
        // On its own azooKey writes した as 下
        #expect(convert("pushshita") == "push した")
        #expect(convert("commit site push simasu") == "commit して push します")
    }

    @Test func convertsNothingToNothing() {
        #expect(convert("") == "")
    }
}
