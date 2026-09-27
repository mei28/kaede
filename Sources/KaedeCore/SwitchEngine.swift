/// What the tap does with a key.
public enum KeyAction: Equatable, Sendable {
    case pass
    /// Hold the key back: the engine returns it once the switch is done.
    case suppress
    /// Suppress the key and send this key code with the key's flags in its place.
    case remap(keyCode: UInt16)
}

/// What Kaede asks Jev about the word being typed.
public struct Question: Equatable, Sendable {
    /// Matches the answer to the question.
    public var id: Int
    /// The word's keys as they show on screen with the Roman source (its last `keysLimit`).
    public var keys: String
    /// The same keys read with Ebi fingering.
    public var ebiReading: String
    /// What was typed before the word in this field.
    public var textBefore: String
    /// The answers Jev may choose from.
    public var options: [Answer]

    public init(id: Int, keys: String, ebiReading: String, textBefore: String, options: [Answer]) {
        self.id = id
        self.keys = keys
        self.ebiReading = ebiReading
        self.textBefore = textBefore
        self.options = options
    }
}

/// How to switch the word to azooKey: delete what its keys put on screen, select azooKey, and
/// type the word's romaji into it.
public struct SwitchOrder: Equatable, Sendable {
    /// The Japanese answer the switch follows.
    public var answer: Answer
    /// Characters the word's keys put on screen.
    public var deleteCount: Int
    /// The word read in the answer's layout, as keys to press in azooKey.
    public var romaji: String

    public init(answer: Answer, deleteCount: Int, romaji: String) {
        self.answer = answer
        self.deleteCount = deleteCount
        self.romaji = romaji
    }
}

/// A finished word: what the dictionary rule would have said, next to what Jev settled
/// (English when the word ended without a switch). Logged to see how often they agree.
public struct WordOutcome: Equatable, Sendable {
    public var rule: Answer
    public var jev: Answer

    public init(rule: Answer, jev: Answer) {
        self.rule = rule
        self.jev = jev
    }

    public var agrees: Bool {
        rule == jev
    }
}

/// What the app does besides handling the key itself.
public struct Reaction: Equatable, Sendable {
    /// A question to send to Jev.
    public var question: Question?
    /// Switch the word to azooKey.
    public var switchOrder: SwitchOrder?
    /// A word of at least `minimumStrokes` keys finished.
    public var finishedWord: WordOutcome?
    /// Enter committed the Japanese in Kaede's azooKey: select the Roman source again, then call
    /// `switchedBack()` or `switchBackFailed()`.
    public var switchBack: Bool

    public init(
        question: Question? = nil, switchOrder: SwitchOrder? = nil,
        finishedWord: WordOutcome? = nil, switchBack: Bool = false
    ) {
        self.question = question
        self.switchOrder = switchOrder
        self.finishedWord = finishedWord
        self.switchBack = switchBack
    }
}

/// Follows the word typed with the Roman source, asks Jev about it, and decides from the answers
/// when to switch it to azooKey.
///
/// Runs on the tap's thread only, and never reads a clock: each call says when it happens, so
/// tests and the evaluation can run on made-up time.
public final class SwitchEngine {
    private let rule: DictionaryRule
    /// The keys of the word being typed: layout keys, and "-" inside the word.
    private var word = Run()
    /// Counts the words, so an answer about an earlier word is known for what it is.
    private var wordNumber = 0
    /// The prefixes of the word asked about already.
    private var asked: [[RunElement]] = []
    /// Questions waiting for an answer, by ID.
    private var waiting: [Int: AskedPrefix] = [:]
    private var lastQuestionID = 0
    /// Jev's answers about prefixes of the word.
    private var answered: [(elements: [RunElement], judgment: Judgment)] = []
    /// When the word last changed, for the pause that settles an answer.
    private var lastKeyAt: ContinuousClock.Instant?
    /// What was typed before the word in this field, as Kaede saw the keys.
    private var textBefore = ""
    private var state = State.watching


    private enum State {
        /// Following the word typed with the Roman source.
        case watching
        /// The word goes to azooKey; keys pressed meanwhile wait.
        case switching(Answer, held: [RawKey])
        /// azooKey takes the keys, read in the layout of the answer Kaede switched on.
        case remapping(Answer)
        /// Enter committed the Japanese and the Roman source is coming back; keys wait.
        case switchingBack(Answer, held: [RawKey])
    }

    /// - Parameters:
    ///   - rule: judges each finished word as well, for the log.
    ///   - textBefore: what was typed before in the field; the evaluation starts mid-sentence.
    public init(rule: DictionaryRule, textBefore: String = "") {
        self.rule = rule
        self.textBefore = String(textBefore.suffix(Tuning.textBeforeLimit))
    }

    /// When a pause would settle the latest answer, if one would.
    public var deadline: ContinuousClock.Instant? {
        guard case .watching = state, let lastKeyAt,
              let pause = SwitchRule.pauseNeeded(answersAboutTheWord, strokes: word.elements.count, englishStart: rule.isEnglishStart(word))
        else { return nil }
        return lastKeyAt + pause
    }

    public func handle(_ key: RawKey, source: InputSource, at instant: ContinuousClock.Instant) -> (KeyAction, Reaction) {
        if key.isKaedeEvent {
            return (.pass, Reaction())
        }
        switch state {
        case .watching:
            break
        case let .switching(answer, held):
            // Keys typed before the word is in azooKey would land in the wrong place
            state = .switching(answer, held: held + [key])
            return (.suppress, Reaction())
        case let .switchingBack(answer, held):
            state = .switchingBack(answer, held: held + [key])
            return (.suppress, Reaction())
        case let .remapping(answer):
            guard let layout = answer.layout else {
                preconditionFailure("remapping on \(answer), which has no layout")
            }
            if source == .azooKey, KeyCode.enter.contains(key.keyCode) {
                // azooKey commits with this Enter; English comes back after it
                state = .switchingBack(answer, held: [])
                return (.pass, Reaction(switchBack: true))
            }
            if source == .azooKey {
                return (remap(key, in: layout), Reaction())
            }
            // Back in English (or elsewhere) without a notification yet
            state = .watching
        }
        guard source == .roman else {
            // Another source (azooKey switched by hand, say) types into the field meanwhile
            return (.pass, Reaction(finishedWord: forgetText()))
        }
        return (.pass, watch(key, at: instant))
    }

    /// Jev's answer to a question. It counts only while the word it is about is still being
    /// typed, however late it comes.
    public func receive(_ judgment: Judgment, to id: Int, at instant: ContinuousClock.Instant) -> Reaction {
        guard let prefix = waiting.removeValue(forKey: id) else {
            preconditionFailure("an answer to question \(id), which is not waiting")
        }
        guard case .watching = state, prefix.wordNumber == wordNumber, word.elements.starts(with: prefix.elements) else {
            return Reaction()
        }
        answered.removeAll { $0.elements == prefix.elements }
        answered.append((prefix.elements, judgment))
        return decide(at: instant)
    }

    /// The question got no answer; its slot is free again.
    public func questionFailed(_ id: Int) {
        guard waiting.removeValue(forKey: id) != nil else {
            preconditionFailure("question \(id) failed, but it is not waiting")
        }
    }

    /// The word is in azooKey: from now on the keys are read in its layout. Returns the keys held
    /// meanwhile, for the app to post again in order.
    public func switchSucceeded() -> [RawKey] {
        guard case let .switching(answer, held) = state, let layout = answer.layout else {
            preconditionFailure("switchSucceeded while not switching")
        }
        remember(word.reading(in: layout))
        startWord()
        state = .remapping(answer)
        return held
    }

    /// azooKey could not be selected: the word stays as typed. Returns the keys held meanwhile.
    public func switchFailed() -> [RawKey] {
        guard case let .switching(_, held) = state else {
            preconditionFailure("switchFailed while not switching")
        }
        // Reported already when the switch was decided
        remember(word.screenText)
        startWord()
        state = .watching
        return held
    }

    /// The Roman source is back after Enter. Returns the keys held meanwhile; a new line starts.
    public func switchedBack() -> [RawKey] {
        guard case let .switchingBack(_, held) = state else {
            preconditionFailure("switchedBack while not switching back")
        }
        state = .watching
        startWord()
        textBefore = ""
        return held
    }

    /// The Roman source could not be selected: azooKey keeps the keys. Returns the keys held meanwhile.
    public func switchBackFailed() -> [RawKey] {
        guard case let .switchingBack(answer, held) = state else {
            preconditionFailure("switchBackFailed while not switching back")
        }
        state = .remapping(answer)
        return held
    }

    /// The selected input source changed, and `source` is selected now. Leaving azooKey (left cmd,
    /// Escape) ends the remapping, so a later right cmd leaves the keys to Hammerspoon's own
    /// remapping. One switch sends several notifications, Kaede's own included, so they are told
    /// apart by the source rather than counted.
    public func inputSourceChanged(to source: InputSource) {
        if case .remapping = state, source != .azooKey {
            state = .watching
            startWord()
        }
    }

    /// Time passed without a key: a pause may have settled the latest answer.
    public func tick(at instant: ContinuousClock.Instant) -> Reaction {
        guard case .watching = state else { return Reaction() }
        return decide(at: instant)
    }

    /// A click or another app: the caret may be anywhere now.
    public func caretMoved() -> Reaction {
        Reaction(finishedWord: forgetText())
    }

    /// Updates the word for a key typed with the Roman source: a question to ask, or the word
    /// finished.
    private func watch(_ key: RawKey, at instant: ContinuousClock.Instant) -> Reaction {
        if KeyCode.enter.contains(key.keyCode) {
            // A line sent or ended: what came before belongs to another message
            let outcome = endWord()
            textBefore = ""
            return Reaction(finishedWord: outcome)
        }
        if key.keyCode == KeyCode.backspace {
            if word.elements.isEmpty {
                // The word before stays ended: its keys may no longer be on screen
                _ = textBefore.popLast()
            } else {
                word.removeLast()
                lastKeyAt = instant
            }
            return Reaction()
        }
        if KeyCode.movingCaret.contains(key.keyCode) || key.hasShortcutModifier {
            return Reaction(finishedWord: forgetText())
        }
        if let position = KeyPosition(keyCode: key.keyCode), !key.isSymbolLayer(at: position) {
            word.append(.stroke(position, shift: key.shift))
            lastKeyAt = instant
            return Reaction(question: ask())
        }
        guard let character = key.printableCharacter else {
            return Reaction(finishedWord: forgetText())
        }
        // A long vowel inside a word (ko-hi-); at its start it is a separator
        if character == "-", !word.elements.isEmpty {
            word.append(.literal(character))
            lastKeyAt = instant
            return Reaction(question: ask())
        }
        let outcome = endWord()
        remember(String(character))
        return Reaction(finishedWord: outcome)
    }

    /// Moving a word to azooKey or English back: Kaede is typing into the app, and its keys wait.
    public var isSwitching: Bool {
        switch state {
        case .switching, .switchingBack: true
        case .watching, .remapping: false
        }
    }

    /// Reading keys through a layout in the azooKey Kaede switched to.
    public var isRemapping: Bool {
        remappingAnswer != nil
    }

    /// The Japanese answer whose layout Kaede reads keys through in its azooKey, if it does.
    public var remappingAnswer: Answer? {
        if case let .remapping(answer) = state { answer } else { nil }
    }

    /// What azooKey gets for a key: the key read in the layout. The text before follows along.
    private func remap(_ key: RawKey, in layout: Layout) -> KeyAction {
        if key.keyCode == KeyCode.backspace {
            _ = textBefore.popLast()
        } else if let position = KeyPosition(keyCode: key.keyCode), !key.hasShortcutModifier {
            remember(String(key.isSymbolLayer(at: position)
                ? Layout.qwerty.character(at: position, shift: true)
                : layout.character(at: position, shift: key.shift)))
        }
        return Remap.keyCode(for: key, in: layout).map { .remap(keyCode: $0) } ?? .pass
    }

    /// A question about the word as it is now, unless it is not worth asking, was asked already,
    /// or too many questions are waiting.
    private func ask() -> Question? {
        guard let options = AskRule.options(for: word), !asked.contains(word.elements),
              waiting.count < Tuning.questionsInFlight
        else { return nil }
        asked.append(word.elements)
        lastQuestionID += 1
        waiting[lastQuestionID] = AskedPrefix(wordNumber: wordNumber, elements: word.elements)
        var sent = Run()
        for element in word.elements.suffix(Tuning.keysLimit) {
            sent.append(element)
        }
        return Question(
            id: lastQuestionID, keys: sent.reading(in: .qwerty), ebiReading: sent.reading(in: .ebi),
            textBefore: textBefore, options: options
        )
    }

    /// Switches the word when the answers about it are settled, and the whole word still reads as
    /// romaji in the answer's layout: typing unreadable keys into azooKey would garble them.
    private func decide(at instant: ContinuousClock.Instant) -> Reaction {
        guard let lastKeyAt,
              let answer = SwitchRule.decide(
                  answersAboutTheWord, strokes: word.elements.count, idle: instant - lastKeyAt,
                  englishStart: rule.isEnglishStart(word)
              ),
              let layout = answer.layout, AskRule.options(for: word)?.contains(answer) == true
        else { return Reaction() }
        state = .switching(answer, held: [])
        return Reaction(
            switchOrder: SwitchOrder(answer: answer, deleteCount: word.screenText.count, romaji: word.reading(in: layout)),
            finishedWord: WordOutcome(rule: rule.judge(word), jev: answer)
        )
    }

    /// The answers about prefixes of the word as it is now, shortest first.
    private var answersAboutTheWord: [AnsweredPrefix] {
        answered.filter { word.elements.starts(with: $0.elements) }
            .sorted { $0.elements.count < $1.elements.count }
            .map { AnsweredPrefix(strokes: $0.elements.count, judgment: $0.judgment) }
    }

    /// The word is done as typed: its keys join the text before, and a new word starts.
    private func endWord() -> WordOutcome? {
        let outcome = outcomeAsTyped
        remember(word.screenText)
        startWord()
        return outcome
    }

    /// A word long enough to have been asked about stayed English.
    private var outcomeAsTyped: WordOutcome? {
        guard word.elements.count >= Tuning.minimumStrokes else { return nil }
        return WordOutcome(rule: rule.judge(word), jev: .english)
    }

    private func startWord() {
        word = Run()
        wordNumber += 1
        asked = []
        answered = []
        lastKeyAt = nil
    }

    /// Drops the word and the text before.
    private func forgetText() -> WordOutcome? {
        let outcome = outcomeAsTyped
        startWord()
        textBefore = ""
        return outcome
    }

    private func remember(_ text: String) {
        textBefore = String((textBefore + text).suffix(Tuning.textBeforeLimit))
    }
}

/// The keys of a word a question was about.
private struct AskedPrefix {
    var wordNumber: Int
    var elements: [RunElement]
}
