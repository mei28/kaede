/// The numbers of an evaluation run: how the words of the table went, and how the dictionary
/// rule alone would have judged them.
public struct WordEvaluationSummary: Sendable {
    public var englishWords = 0
    /// English words switched to Japanese: the worst mistake, as the word is lost to azooKey.
    public var englishSwitched = 0
    public var japaneseWords = 0
    /// Japanese words switched in their own layout.
    public var japaneseSwitched = 0
    public var japaneseWrongLayout = 0
    /// Japanese words left as typed.
    public var japaneseMissed = 0
    /// Keys typed when each Japanese word switched in its own layout.
    public var keysToSwitch: [Int] = []
    public var questionsAsked = 0
    /// Words the dictionary rule judges as what they are, from all their keys.
    public var ruleCorrect = 0

    public init(results: [SimulatedWord], rule: DictionaryRule) {
        for result in results {
            questionsAsked += result.questionsAsked
            if rule.judge(Run(typing: result.word.keys)) == result.word.answer {
                ruleCorrect += 1
            }
            if result.word.answer == .english {
                englishWords += 1
                if result.switchedTo != nil { englishSwitched += 1 }
                continue
            }
            japaneseWords += 1
            switch result.verdict {
            case .correct:
                japaneseSwitched += 1
                keysToSwitch.append(result.keysAtSwitch!)
            case .wrongSwitch:
                japaneseWrongLayout += 1
            case .missed:
                japaneseMissed += 1
            }
        }
    }
}
