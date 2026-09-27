/// Jev's answer to a question, and how long it took to come.
public struct TimedJudgment: Sendable {
    public var judgment: Judgment
    public var latency: Duration

    public init(judgment: Judgment, latency: Duration) {
        self.judgment = judgment
        self.latency = latency
    }
}

/// How a word of the evaluation table went through the engine.
public struct SimulatedWord: Equatable, Sendable {
    /// The word itself, with what it is.
    public var word: WordCase
    /// The Japanese answer it switched on, or nil when it stayed as typed.
    public var switchedTo: Answer?
    /// Keys typed when it switched.
    public var keysAtSwitch: Int?
    public var questionsAsked: Int

    public enum Verdict: Sendable {
        case correct
        /// English switched, or Japanese switched in the other layout.
        case wrongSwitch
        /// Japanese stayed as typed.
        case missed
    }

    public var verdict: Verdict {
        switch (word.answer, switchedTo) {
        case (.english, nil): .correct
        case (_, nil): .missed
        case let (expected, switched?): expected == switched ? .correct : .wrongSwitch
        }
    }
}

/// Types a word of the evaluation table into the engine on made-up time, with answers fetched
/// beforehand, so an evaluation run asks Jev each question once whatever the timing.
public enum Simulation {
    /// Keys come at this pace.
    public static let keyInterval: Duration = .milliseconds(150)
    /// The hands rest this long after the word before its space: the pause that settles an
    /// answer, as it happens in real typing.
    public static let endPause: Duration = .milliseconds(500)

    /// The questions the engine may ask about the word: one per prefix it would ask about.
    public static func questions(for word: WordCase) -> [Question] {
        let textBefore = String(word.textBefore.suffix(Tuning.textBeforeLimit))
        return (1...word.keys.count).compactMap { length in
            let prefix = Run(typing: String(word.keys.prefix(length)))
            guard let options = AskRule.options(for: prefix) else { return nil }
            return Question(
                id: length, keys: prefix.reading(in: .qwerty), ebiReading: prefix.reading(in: .ebi),
                textBefore: textBefore, options: options
            )
        }
    }

    /// - Parameter answers: an answer for each question of `questions(for:)`, by its keys.
    public static func run(_ word: WordCase, rule: DictionaryRule, answers: [String: TimedJudgment]) -> SimulatedWord {
        let engine = SwitchEngine(rule: rule, textBefore: word.textBefore)
        let start = ContinuousClock.now
        var keys = word.keys.enumerated().map { index, character in
            (at: start + keyInterval * index, key: key(typing: character))
        }
        keys.append((at: keys[keys.count - 1].at + endPause, key: key(typing: " ")))
        var waiting: [(at: ContinuousClock.Instant, id: Int, judgment: Judgment)] = []
        var asked = 0
        var lastTick: ContinuousClock.Instant?

        /// Delivers the answers and ticks due by `instant`, in time order; returns a switch.
        func runUntil(_ instant: ContinuousClock.Instant) -> SwitchOrder? {
            while true {
                let answer = waiting.indices.min { waiting[$0].at < waiting[$1].at }
                let answerAt = answer.map { waiting[$0].at }
                // A deadline already ticked stays put when the switch it allows cannot happen
                let deadline = engine.deadline.flatMap { $0 == lastTick ? nil : $0 }
                let reaction: Reaction
                if let answer, let answerAt, answerAt <= instant, deadline.map({ answerAt <= $0 }) ?? true {
                    let (_, id, judgment) = waiting.remove(at: answer)
                    reaction = engine.receive(judgment, to: id, at: answerAt)
                } else if let deadline, deadline <= instant {
                    lastTick = deadline
                    reaction = engine.tick(at: deadline)
                } else {
                    return nil
                }
                if let order = reaction.switchOrder {
                    return order
                }
            }
        }

        for (at, key) in keys {
            if let order = runUntil(at) {
                return SimulatedWord(word: word, switchedTo: order.answer, keysAtSwitch: order.deleteCount, questionsAsked: asked)
            }
            if let question = engine.handle(key, source: .roman, at: at).1.question {
                guard let answer = answers[question.keys] else {
                    preconditionFailure("no answer fetched for the question about \(question.keys)")
                }
                asked += 1
                waiting.append((at + answer.latency, question.id, answer.judgment))
            }
        }
        return SimulatedWord(word: word, switchedTo: nil, keysAtSwitch: nil, questionsAsked: asked)
    }

    /// The key that types `character` with the Roman source: a layout key, Space or "-".
    private static func key(typing character: Character) -> RawKey {
        let lowered = Character(character.lowercased())
        if let position = KeyPosition.allCases.first(where: { $0.qwertyCharacter == lowered }) {
            return RawKey(keyCode: position.keyCode, character: character, shift: character != lowered)
        }
        switch character {
        case " ": return RawKey(keyCode: KeyCode.space, character: " ")
        case "-": return RawKey(keyCode: 27, character: "-")
        default: preconditionFailure("the evaluation table holds a key Kaede cannot type: \(character)")
        }
    }
}
