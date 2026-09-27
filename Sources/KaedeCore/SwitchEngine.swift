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

/// What the app does besides handling the key itself.
public struct Reaction: Equatable, Sendable {
    /// A question to send to Jev.
    public var question: Question?
    /// Switch the word to azooKey.
    public var switchOrder: SwitchOrder?

    public init(question: Question? = nil, switchOrder: SwitchOrder? = nil) {
        self.question = question
        self.switchOrder = switchOrder
    }
}

/// Follows the word typed with the Roman source, asks Jev about it, and decides from the answers
/// when to switch it to azooKey.
///
/// Runs on the tap's thread only, and never reads a clock: each call says when it happens, so
/// tests and the evaluation can run on made-up time.
public final class SwitchEngine {
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

    /// Notifications of input source changes that Kaede's own switch will cause.
    private var ownSwitchNotifications = 0

    private enum State {
        /// Following the word typed with the Roman source.
        case watching
        /// The word goes to azooKey; keys pressed meanwhile wait.
        case switching(Answer, held: [RawKey])
        /// azooKey takes the keys, read in the layout of the word Kaede switched.
        case remapping(Layout)
    }

    public init() {}

    /// When a pause would settle the latest answer, if one would.
    public var deadline: ContinuousClock.Instant? {
        guard case .watching = state, let lastKeyAt,
              let pause = SwitchRule.pauseNeeded(answersAboutTheWord, strokes: word.elements.count)
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
        case let .remapping(layout):
            if source == .azooKey {
                return (remap(key, in: layout), Reaction())
            }
            // Back in English (or elsewhere) without a notification yet
            state = .watching
        }
        guard source == .roman else {
            // Another source (azooKey switched by hand, say) types into the field meanwhile
            forgetText()
            return (.pass, Reaction())
        }
        return (.pass, Reaction(question: watch(key, at: instant)))
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
        state = .remapping(layout)
        return held
    }

    /// azooKey could not be selected: the word stays as typed. Returns the keys held meanwhile.
    public func switchFailed() -> [RawKey] {
        guard case let .switching(_, held) = state else {
            preconditionFailure("switchFailed while not switching")
        }
        ownSwitchNotifications = 0
        endWord()
        state = .watching
        return held
    }

    /// The selected input source changed. Apart from Kaede's own switch, the user switched (left
    /// cmd, or Hammerspoon's right cmd with its own remapping), so Kaede stops remapping.
    public func inputSourceChanged() {
        if ownSwitchNotifications > 0 {
            ownSwitchNotifications -= 1
            return
        }
        if case .remapping = state {
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
        forgetText()
        return Reaction()
    }

    /// Updates the word for a key typed with the Roman source, and returns the question to ask.
    private func watch(_ key: RawKey, at instant: ContinuousClock.Instant) -> Question? {
        if KeyCode.enter.contains(key.keyCode) {
            // A line sent or ended: what came before belongs to another message
            endWord()
            textBefore = ""
            return nil
        }
        if key.keyCode == KeyCode.backspace {
            if word.elements.isEmpty {
                // The word before stays ended: its keys may no longer be on screen
                _ = textBefore.popLast()
            } else {
                word.removeLast()
                lastKeyAt = instant
            }
            return nil
        }
        if KeyCode.resettingRun.contains(key.keyCode) || key.hasShortcutModifier {
            forgetText()
            return nil
        }
        if let position = KeyPosition(keyCode: key.keyCode), !key.isSymbolLayer(at: position) {
            word.append(.stroke(position, shift: key.shift))
            lastKeyAt = instant
            return ask()
        }
        guard let character = key.printableCharacter else {
            forgetText()
            return nil
        }
        // A long vowel inside a word (ko-hi-); at its start it is a separator
        if character == "-", !word.elements.isEmpty {
            word.append(.literal(character))
            lastKeyAt = instant
            return ask()
        }
        endWord()
        remember(String(character))
        return nil
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
              let answer = SwitchRule.decide(answersAboutTheWord, strokes: word.elements.count, idle: instant - lastKeyAt),
              let layout = answer.layout, AskRule.options(for: word)?.contains(answer) == true
        else { return Reaction() }
        state = .switching(answer, held: [])
        ownSwitchNotifications = 1
        return Reaction(switchOrder: SwitchOrder(
            answer: answer, deleteCount: word.screenText.count, romaji: word.reading(in: layout)
        ))
    }

    /// The answers about prefixes of the word as it is now, shortest first.
    private var answersAboutTheWord: [AnsweredPrefix] {
        answered.filter { word.elements.starts(with: $0.elements) }
            .sorted { $0.elements.count < $1.elements.count }
            .map { AnsweredPrefix(strokes: $0.elements.count, judgment: $0.judgment) }
    }

    /// The word is done: its keys join the text before, and a new word starts.
    private func endWord() {
        remember(word.screenText)
        startWord()
    }

    private func startWord() {
        word = Run()
        wordNumber += 1
        asked = []
        answered = []
        lastKeyAt = nil
    }

    /// Drops the word and the text before.
    private func forgetText() {
        startWord()
        textBefore = ""
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
