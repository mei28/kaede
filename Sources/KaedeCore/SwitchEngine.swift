/// What the tap does with a key.
public enum KeyAction: Equatable, Sendable {
    case pass
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

/// What the app does besides handling the key itself.
public struct Reaction: Equatable, Sendable {
    /// A question to send to Jev.
    public var question: Question?

    public init(question: Question? = nil) {
        self.question = question
    }
}

/// Follows the word typed with the Roman source and decides when to ask Jev about it.
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
    /// What was typed before the word in this field, as Kaede saw the keys.
    private var textBefore = ""

    public init() {}

    public func handle(_ key: RawKey, source: InputSource, at instant: ContinuousClock.Instant) -> (KeyAction, Reaction) {
        if key.isKaedeEvent {
            return (.pass, Reaction())
        }
        guard source == .roman else {
            // Another source (azooKey switched by hand, say) types into the field meanwhile
            forgetText()
            return (.pass, Reaction())
        }
        return (.pass, Reaction(question: watch(key)))
    }

    /// The question got no answer; its slot is free again.
    public func questionFailed(_ id: Int) {
        waiting[id] = nil
    }

    /// A click or another app: the caret may be anywhere now.
    public func caretMoved() -> Reaction {
        forgetText()
        return Reaction()
    }

    /// Updates the word for a key typed with the Roman source, and returns the question to ask.
    private func watch(_ key: RawKey) -> Question? {
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
            }
            return nil
        }
        if KeyCode.resettingRun.contains(key.keyCode) || key.hasShortcutModifier {
            forgetText()
            return nil
        }
        if let position = KeyPosition(keyCode: key.keyCode), !key.isSymbolLayer(at: position) {
            word.append(.stroke(position, shift: key.shift))
            return ask()
        }
        guard let character = key.printableCharacter else {
            forgetText()
            return nil
        }
        // A long vowel inside a word (ko-hi-); at its start it is a separator
        if character == "-", !word.elements.isEmpty {
            word.append(.literal(character))
            return ask()
        }
        endWord()
        remember(String(character))
        return nil
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

    /// The word is done: its keys join the text before, and a new word starts.
    private func endWord() {
        remember(word.screenText)
        startWord()
    }

    private func startWord() {
        word = Run()
        wordNumber += 1
        asked = []
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
