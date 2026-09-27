/// Jev's answer about the first `strokes` keys of the word being typed.
public struct AnsweredPrefix: Equatable, Sendable {
    public var strokes: Int
    public var judgment: Judgment

    public init(strokes: Int, judgment: Judgment) {
        self.strokes = strokes
        self.judgment = judgment
    }
}

/// When Jev's answers about a growing word are settled enough to switch to Japanese
/// (jev-auto-ime's rule: an answer to a growing prefix wavers, so one answer is not enough).
public enum SwitchRule {
    /// The Japanese answer to switch to, or nil to keep waiting.
    /// - Parameters:
    ///   - answers: the answers about the word, fewest strokes first.
    ///   - strokes: the word's strokes now.
    ///   - idle: how long ago the last key was pressed.
    public static func decide(_ answers: [AnsweredPrefix], strokes: Int, idle: Duration) -> Answer? {
        guard let latest = answers.last, isCandidate(latest) else { return nil }
        let recent = answers.suffix(Tuning.streakLength)
        let opposed = isOpposed(latest, within: recent)
        if latest.judgment.confidence >= Tuning.immediateConfidence && !opposed {
            return latest.judgment.answer
        }
        if isStreak(recent) {
            return latest.judgment.answer
        }
        if let pause = pauseNeeded(answers, strokes: strokes), idle >= pause {
            return latest.judgment.answer
        }
        return nil
    }

    /// How long a pause after the last key would switch on the latest answer; nil when no pause
    /// would. Only an answer about the whole word counts, as more keys may change it.
    public static func pauseNeeded(_ answers: [AnsweredPrefix], strokes: Int) -> Duration? {
        guard let latest = answers.last, isCandidate(latest), latest.strokes == strokes,
              latest.judgment.confidence >= Tuning.confidence
        else { return nil }
        guard isOpposed(latest, within: answers.suffix(Tuning.streakLength)) else {
            return Tuning.pause
        }
        return latest.judgment.confidence >= Tuning.immediateConfidence ? Tuning.opposedPause : nil
    }

    /// A Japanese answer about enough keys, above the floor.
    private static func isCandidate(_ answer: AnsweredPrefix) -> Bool {
        [.japaneseQwerty, .japaneseEbi].contains(answer.judgment.answer)
            && answer.strokes >= Tuning.minimumStrokes
            && answer.judgment.confidence >= Tuning.confidenceFloor
    }

    /// Whether a recent answer says otherwise with some confidence: English, or Japanese in the
    /// other layout. keep says nothing.
    private static func isOpposed(_ latest: AnsweredPrefix, within recent: ArraySlice<AnsweredPrefix>) -> Bool {
        recent.contains { other in
            other.judgment.answer != latest.judgment.answer && other.judgment.answer != .keep
                && other.judgment.confidence >= Tuning.confidence
        }
    }

    /// The same answer about each of the last few prefixes, one stroke apart, confident enough
    /// on average and each above the floor.
    private static func isStreak(_ recent: ArraySlice<AnsweredPrefix>) -> Bool {
        guard recent.count == Tuning.streakLength, let first = recent.first else { return false }
        let oneStrokeApart = zip(recent, recent.dropFirst()).allSatisfy { $1.strokes == $0.strokes + 1 }
        let agreeing = recent.allSatisfy {
            $0.judgment.answer == first.judgment.answer && $0.judgment.confidence >= Tuning.confidenceFloor
        }
        let average = recent.map(\.judgment.confidence).reduce(0, +) / Double(recent.count)
        return oneStrokeApart && agreeing && average >= Tuning.confidence
    }
}
