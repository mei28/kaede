import Testing
@testable import KaedeCore

/// An answer to the first `strokes` keys of the word.
private func answer(_ strokes: Int, _ answer: Answer, _ confidence: Double) -> AnsweredPrefix {
    AnsweredPrefix(strokes: strokes, judgment: Judgment(answer: answer, confidence: confidence))
}

@Suite struct SwitchRuleTests {
    @Test func fewerThanThreeStrokesNeverSwitch() {
        #expect(SwitchRule.decide([answer(2, .japaneseEbi, 0.99)], strokes: 2, idle: .seconds(1), englishStart: false) == nil)
    }

    @Test func aConfidentAnswerWithNothingOpposingSwitchesAtOnce() {
        // Even while the letters may still become an English word
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.92)], strokes: 3, idle: .zero, englishStart: true) == .japaneseEbi)
        // keep opposes nothing
        #expect(SwitchRule.decide([answer(3, .keep, 0.9), answer(4, .japaneseEbi, 0.92)], strokes: 4, idle: .zero, englishStart: true) == .japaneseEbi)
    }

    @Test func anOpposingAnswerAmongTheLastThreeHoldsTheSwitch() {
        #expect(SwitchRule.decide([answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.92)], strokes: 4, idle: .zero, englishStart: false) == nil)
        // The other layout opposes too
        #expect(SwitchRule.decide([answer(3, .japaneseQwerty, 0.6), answer(4, .japaneseEbi, 0.92)], strokes: 4, idle: .zero, englishStart: false) == nil)
        // Below 0.55 an answer opposes nothing
        #expect(SwitchRule.decide([answer(3, .english, 0.5), answer(4, .japaneseEbi, 0.92)], strokes: 4, idle: .zero, englishStart: true) == .japaneseEbi)
        // Four answers back is too far to oppose
        let old = [answer(3, .english, 0.9), answer(4, .keep, 0.5), answer(5, .keep, 0.5), answer(6, .japaneseEbi, 0.92)]
        #expect(SwitchRule.decide(old, strokes: 6, idle: .zero, englishStart: true) == .japaneseEbi)
    }

    @Test func lettersThatMayStillBeEnglishSwitchOnlyOnAVeryConfidentAnswer() {
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.89)], strokes: 3, idle: .seconds(1), englishStart: true) == nil)
        let agreeing = [answer(3, .japaneseEbi, 0.7), answer(4, .japaneseEbi, 0.7), answer(5, .japaneseEbi, 0.7)]
        #expect(SwitchRule.decide(agreeing, strokes: 5, idle: .seconds(1), englishStart: true) == nil)
    }

    @Test func lettersNoEnglishWordStartsWithSwitchOnAModestAnswer() {
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.45)], strokes: 3, idle: .zero, englishStart: false) == .japaneseEbi)
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.44)], strokes: 3, idle: .zero, englishStart: false) == nil)
        #expect(SwitchRule.decide([answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.6)], strokes: 4, idle: .zero, englishStart: false) == nil)
    }

    @Test func threeAgreeingAnswersInARowSwitchEvenWhenTheLatestIsModest() {
        let agreeing = [answer(3, .japaneseEbi, 0.7), answer(4, .japaneseEbi, 0.7), answer(5, .japaneseEbi, 0.4)]
        #expect(SwitchRule.decide(agreeing, strokes: 5, idle: .zero, englishStart: false) == .japaneseEbi)
    }

    @Test func aStreakNeedsEachAnswerAboveTheFloorAndTheAverage() {
        let lowOne = [answer(3, .japaneseEbi, 0.3), answer(4, .japaneseEbi, 0.7), answer(5, .japaneseEbi, 0.4)]
        #expect(SwitchRule.decide(lowOne, strokes: 5, idle: .zero, englishStart: false) == nil)
        let lowAverage = [answer(3, .japaneseEbi, 0.5), answer(4, .japaneseEbi, 0.56), answer(5, .japaneseEbi, 0.4)]
        #expect(SwitchRule.decide(lowAverage, strokes: 5, idle: .zero, englishStart: false) == nil)
    }

    @Test func aStreakNeedsConsecutiveStrokesAndOneLayout() {
        let gap = [answer(3, .japaneseEbi, 0.6), answer(4, .japaneseEbi, 0.6), answer(6, .japaneseEbi, 0.4)]
        #expect(SwitchRule.decide(gap, strokes: 6, idle: .zero, englishStart: false) == nil)
        let mixed = [answer(3, .japaneseQwerty, 0.6), answer(4, .japaneseEbi, 0.6), answer(5, .japaneseEbi, 0.4)]
        #expect(SwitchRule.decide(mixed, strokes: 5, idle: .zero, englishStart: false) == nil)
    }

    @Test func aPauseAgainstAnOpposingAnswerNeedsLongerAndMoreConfidence() {
        let confident = [answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.95)]
        #expect(SwitchRule.decide(confident, strokes: 4, idle: .milliseconds(699), englishStart: false) == nil)
        #expect(SwitchRule.decide(confident, strokes: 4, idle: .milliseconds(700), englishStart: false) == .japaneseEbi)
        let unsure = [answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.85)]
        #expect(SwitchRule.decide(unsure, strokes: 4, idle: .seconds(1), englishStart: false) == nil)
        // Only an answer about the whole word counts: a key came after the question
        #expect(SwitchRule.decide(confident, strokes: 5, idle: .seconds(1), englishStart: false) == nil)
    }

    @Test func onlyAJapaneseLatestAnswerSwitches() {
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.95), answer(4, .english, 0.9)], strokes: 4, idle: .seconds(1), englishStart: false) == nil)
        #expect(SwitchRule.decide([answer(3, .japaneseEbi, 0.95), answer(4, .keep, 0.9)], strokes: 4, idle: .seconds(1), englishStart: false) == nil)
    }

    @Test func thePauseNeededIsKnownBeforeItPasses() {
        #expect(SwitchRule.pauseNeeded([answer(3, .japaneseEbi, 0.6)], strokes: 3, englishStart: false) == .milliseconds(350))
        #expect(SwitchRule.pauseNeeded([answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.95)], strokes: 4, englishStart: false) == .milliseconds(700))
        #expect(SwitchRule.pauseNeeded([answer(3, .english, 0.6), answer(4, .japaneseEbi, 0.85)], strokes: 4, englishStart: false) == nil)
        #expect(SwitchRule.pauseNeeded([answer(3, .english, 0.9)], strokes: 3, englishStart: false) == nil)
        #expect(SwitchRule.pauseNeeded([answer(3, .japaneseEbi, 0.6)], strokes: 4, englishStart: false) == nil)
        // No pause switches letters that may still be English
        #expect(SwitchRule.pauseNeeded([answer(3, .japaneseEbi, 0.6)], strokes: 3, englishStart: true) == nil)
    }
}
