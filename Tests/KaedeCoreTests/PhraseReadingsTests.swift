import Testing
@testable import KaedeCore

@Suite struct PhraseReadingsTests {
    @Test func shrinkingTheLastPhraseStartsANewOne() {
        #expect(PhraseReadings.resized(["きょうはてんき"], at: 0, by: -1) == ["きょうはてん", "き"])
    }

    @Test func shrinkingGivesTheLastCharacterToTheNextPhrase() {
        #expect(PhraseReadings.resized(["きょうはて", "んき"], at: 0, by: -1) == ["きょうは", "てんき"])
    }

    @Test func extendingTakesTheFirstCharacterOfTheNextPhrase() {
        #expect(PhraseReadings.resized(["きょうは", "てんき"], at: 0, by: 1) == ["きょうはて", "んき"])
    }

    @Test func extendingOverAOneCharacterPhraseRemovesIt() {
        #expect(PhraseReadings.resized(["きょうはてん", "き"], at: 0, by: 1) == ["きょうはてんき"])
    }

    @Test func resizesAPhraseInTheMiddle() {
        #expect(PhraseReadings.resized(["きょうは", "てんきが", "いい"], at: 1, by: -1) == ["きょうは", "てんき", "がいい"])
    }

    @Test func cannotShrinkAPhraseOfOneCharacter() {
        #expect(PhraseReadings.resized(["き", "ょう"], at: 0, by: -1) == nil)
    }

    @Test func cannotExtendTheLastPhrase() {
        #expect(PhraseReadings.resized(["きょうは", "てんき"], at: 1, by: 1) == nil)
    }
}
