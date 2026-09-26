/// A key-down event as the tap sees it, stripped of AppKit types.
public struct RawKey: Equatable, Sendable {
    public var keyCode: UInt16
    /// The character the event types under the current input source, if any.
    public var character: Character?
    public var shift: Bool
    /// Right Shift specifically (the device-dependent flag bit).
    public var rightShift: Bool
    public var command: Bool
    public var control: Bool
    public var option: Bool
    /// Posted by Kaede itself (marked through `kCGEventSourceUserData`).
    public var isKaedeEvent: Bool

    public init(
        keyCode: UInt16, character: Character?,
        shift: Bool = false, rightShift: Bool = false,
        command: Bool = false, control: Bool = false, option: Bool = false,
        isKaedeEvent: Bool = false
    ) {
        self.keyCode = keyCode
        self.character = character
        self.shift = shift
        self.rightShift = rightShift
        self.command = command
        self.control = control
        self.option = option
        self.isKaedeEvent = isKaedeEvent
    }
}

/// macOS virtual key codes of the keys with their own rules.
enum KeyCode {
    static let backspace: UInt16 = 51
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    /// Return and keypad Enter.
    static let enter: Set<UInt16> = [36, 76]
    /// Keys that move the caret or leave the text: Tab, Escape, and the four arrows.
    static let resettingRun: Set<UInt16> = [48, 53, 123, 124, 125, 126]
}

/// What the tap does with the event it just received.
public enum KeyResponse: Equatable, Sendable {
    case pass
    /// Suppress the event; the engine holds it until the replacement finishes.
    case suppress
    /// Suppress the event and replace the run on screen.
    case replace(Replacement)
    /// Suppress the event, delete `deleteCount` characters before the caret and type `text`.
    case rewrite(deleteCount: Int, text: String)
    /// Suppress the event and hand the run's last Japanese part to azooKey.
    case handOff(HandOff)
    /// Suppress the event and ask whether the word is Japanese or English; pass the answer
    /// to `answerLanguage(_:)`.
    case askLanguage(LanguageQuestion)
}

/// Tracks the run and decides, per event, what the tap does. Runs on the tap's thread only.
public final class KeyEngine {
    private let planner: EnterPlanner
    private(set) var run = Run()
    /// Keys pressed while a replacement is being typed, or nil when none is in progress.
    /// Letting them through would race the replacement: a second Enter could send the half-replaced text.
    private var heldKeys: [RawKey]?
    /// The replacement being typed, until its candidates arrive.
    private var pendingReplacement: Replacement?
    /// Whether the user may step through the pending replacement's candidates afterwards.
    private var pendingCorrectable = false
    /// The ambiguous word waiting for its language.
    private var pendingQuestion: Run?
    /// Words recently finished in this field, as Kaede read them: context for questions.
    private var recentText = ""
    /// jev-auto-ime sends the last 240 characters before the caret.
    static let recentTextLimit = 240
    /// The last conversion, while the user can still step through its candidates.
    private var correction: Correction?

    /// Whether ambiguous words are asked about (Jev is set up); otherwise the rules settle them.
    private let asksLanguage: Bool

    public init(planner: EnterPlanner, asksLanguage: Bool = false) {
        self.planner = planner
        self.asksLanguage = asksLanguage
    }

    /// The caret may have moved: a click or a switch to another app. Ends correcting too.
    public func discardRun() {
        run = Run()
        correction = nil
        recentText = ""
    }

    /// Settles the word that `.askLanguage` asked about. The Space that ended it was suppressed,
    /// so a word that stays as typed gets its Space typed back.
    public func answerLanguage(_ answer: LanguageAnswer) -> KeyResponse {
        guard let word = pendingQuestion else {
            preconditionFailure("answerLanguage called with no question pending")
        }
        pendingQuestion = nil
        let response: KeyResponse
        switch answer {
        case .failed:
            remember(word.screenText)
            response = .pass
        case .japanese:
            response = settle(word, preferring: .japanese)
        case .english:
            response = settle(word, preferring: .english)
        case .undecided:
            response = settle(word, preferring: nil)
        }
        return response == .pass ? .rewrite(deleteCount: 0, text: " ") : response
    }

    public func handle(_ key: RawKey) -> KeyResponse {
        if key.isKaedeEvent {
            return .pass
        }
        if heldKeys != nil {
            heldKeys?.append(key)
            return .suppress
        }
        if let correction {
            if let response = correct(correction, with: key) {
                return response
            }
            // Any other key settles the conversion and is handled as usual
            self.correction = nil
        }
        if KeyCode.enter.contains(key.keyCode) {
            // Enter converts and commits at once; the user can still step through candidates
            recentText = ""
            return endRun(suffix: "", handsOffToAzooKey: false)
        }
        if key.keyCode == KeyCode.space, !key.command, !key.control, !key.option {
            // Words never share a segment across a space, so the word before it can convert now.
            // This is the one place that decides when Japanese goes to azooKey.
            return endWord()
        }
        record(key)
        return .pass
    }

    /// Ends the replacement and returns the held keys, in the order they were pressed, for
    /// the caller to post again as fresh input. With candidates (the first being the text now
    /// on screen), the user can step through them until the next other key; without, the
    /// conversion failed and there is nothing to step through.
    public func finishReplacement(candidates: [String]) -> [RawKey] {
        guard let replacement = pendingReplacement else {
            preconditionFailure("finishReplacement called with no replacement in progress")
        }
        pendingReplacement = nil
        if pendingCorrectable, !candidates.isEmpty {
            correction = Correction(typed: replacement.typed, suffix: replacement.suffix, candidates: candidates, index: 0)
        }
        return releaseHeldKeys()
    }

    /// Ends a hand-off and returns the keys held meanwhile. From here azooKey holds the word
    /// and handles every key until the user switches back to English; the tap skips keys
    /// while the input source is not English.
    public func finishHandOff() -> [RawKey] {
        releaseHeldKeys()
    }

    /// Ends a rewrite and returns the keys held meanwhile.
    public func finishRewrite() -> [RawKey] {
        releaseHeldKeys()
    }

    private func releaseHeldKeys() -> [RawKey] {
        guard let keys = heldKeys else {
            preconditionFailure("no replacement or rewrite in progress")
        }
        heldKeys = nil
        return keys
    }

    /// Space and Shift+Space step through the candidates, Escape restores what was typed.
    /// Returns nil for any other key.
    private func correct(_ correction: Correction, with key: RawKey) -> KeyResponse? {
        guard !key.command, !key.control, !key.option else { return nil }
        let onScreen = correction.shown + correction.suffix
        switch key.keyCode {
        case KeyCode.space:
            var next = correction
            next.index = (correction.index + (key.shift ? -1 : 1) + correction.candidates.count) % correction.candidates.count
            self.correction = next
            heldKeys = []
            return .rewrite(deleteCount: onScreen.count, text: next.shown + next.suffix)
        case KeyCode.escape:
            self.correction = nil
            heldKeys = []
            return .rewrite(deleteCount: onScreen.count, text: correction.typed + correction.suffix)
        default:
            return nil
        }
    }

    /// Updates the run for a key that passes through.
    private func record(_ key: RawKey) {
        if key.keyCode == KeyCode.backspace {
            run.removeLast()
        } else if KeyCode.resettingRun.contains(key.keyCode) || key.command || key.control || key.option {
            // The caret may have moved away from the recent words
            run = Run()
            recentText = ""
        } else if let position = KeyPosition(keyCode: key.keyCode) {
            run.append(Self.isSymbolLayer(key, at: position)
                ? .literal(Layout.qwerty.character(at: position, shift: true))
                : .stroke(position, shift: key.shift))
        } else if let character = key.character, Self.isPrintable(character) {
            run.append(.literal(character))
        } else {
            run = Run()
        }
    }

    /// Ends the word at a Space: asks for the language of an ambiguous word, settles the rest.
    private func endWord() -> KeyResponse {
        let word = run
        run = Run()
        if asksLanguage, planner.isAmbiguous(word) {
            heldKeys = []
            pendingQuestion = word
            return .askLanguage(LanguageQuestion(
                typed: word.screenText, ebiReading: word.reading(in: .ebi), textBefore: recentText
            ))
        }
        return settle(word, preferring: nil)
    }

    /// Hands the word to azooKey, replaces it, or lets it pass, in `language` for its
    /// ambiguous parts. Keeps keys already held while a question was pending.
    private func settle(_ word: Run, preferring language: Language?) -> KeyResponse {
        switch planner.plan(word, preferring: language) {
        case .pass:
            remember(word.screenText)
            return .pass
        case let .convert(pieces):
            if heldKeys == nil { heldKeys = [] }
            if let handOff = planner.handOff(for: word, preferring: language) {
                remember(Self.reading(of: handOff.settled) + handOff.romaji)
                return .handOff(handOff)
            }
            remember(Self.reading(of: pieces))
            let replacement = Replacement(typed: word.screenText, pieces: pieces, suffix: " ")
            pendingReplacement = replacement
            // A Space conversion that could not go to azooKey (the word ends in English) is
            // committed as is; only a conversion by Enter can be stepped through
            pendingCorrectable = false
            return .replace(replacement)
        }
    }

    /// Adds a finished word to the context, keeping the most recent characters.
    private func remember(_ word: String) {
        recentText = String((recentText + word + " ").suffix(Self.recentTextLimit))
    }

    private static func reading(of pieces: [ConversionPiece]) -> String {
        pieces.map { piece in
            switch piece {
            case let .romaji(text), let .verbatim(text): text
            }
        }.joined()
    }

    /// Plans the run and starts a new one. When the run converts, the key that ended it is
    /// suppressed, and `suffix` is what it would have typed after the converted text.
    private func endRun(suffix: String, handsOffToAzooKey: Bool) -> KeyResponse {
        let decision = planner.plan(run)
        let typed = run.screenText
        let runBeforeReset = run
        run = Run()
        switch decision {
        case .pass:
            return .pass
        case let .convert(pieces):
            heldKeys = []
            if handsOffToAzooKey, let handOff = planner.handOff(for: runBeforeReset) {
                return .handOff(handOff)
            }
            let replacement = Replacement(typed: typed, pieces: pieces, suffix: suffix)
            pendingReplacement = replacement
            // Only a conversion by Enter can be stepped through; a Space conversion that could not
            // go to azooKey (the word ends in English) is committed as is
            pendingCorrectable = !handsOffToAzooKey
            return .replace(replacement)
        }
    }

    /// Function keys carry private-use characters and editing keys carry control characters.
    private static func isPrintable(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            ![.control, .privateUse].contains(scalar.properties.generalCategory)
        }
    }

    /// The custom keyboard sends ? : < > from its symbol layer with right Shift. The built-in
    /// keyboard's right Shift sets the same bit, so only these four keys honor it.
    private static func isSymbolLayer(_ key: RawKey, at position: KeyPosition) -> Bool {
        key.rightShift && [.semicolon, .comma, .period, .slash].contains(position)
    }
}

/// The last conversion and the candidates the user can step through.
struct Correction: Equatable {
    /// The run's text before conversion, restored by Escape.
    var typed: String
    /// Typed after the conversion and kept while stepping ("" when Enter converted).
    var suffix: String
    var candidates: [String]
    var index: Int

    var shown: String {
        candidates[index]
    }
}
