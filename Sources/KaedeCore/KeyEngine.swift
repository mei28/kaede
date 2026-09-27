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
    /// Suppress the event and ask whether to respace English typed without spaces; pass the
    /// answer to `answerSpacing(_:)`.
    case askSpacing(SpacingQuestion)
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
    /// The pending question as recorded ("language: …", "spacing: …").
    private var pendingQuestionText: String?
    /// Receives each settled word; set only when the user turned the record on.
    public var recordWord: ((WordRecord) -> Void)?
    /// Words recently finished in this field, as Kaede read them: context for questions.
    private var recentText = ""
    /// jev-auto-ime sends the last 240 characters before the caret.
    public static let recentTextLimit = 240
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
        let asked = (pendingQuestionText, String(describing: answer))
        let response: KeyResponse
        switch answer {
        case .failed:
            response = keepAsTyped(word, asked: asked)
        case .japanese:
            response = settle(word, preferring: .japanese, asked: asked)
        case .english:
            response = settle(word, preferring: .english, asked: asked)
        case .undecided:
            response = settle(word, asked: asked)
        }
        return response == .pass ? .rewrite(deleteCount: 0, text: " ") : response
    }

    /// Settles the word that `.askSpacing` asked about, as `answerLanguage(_:)` does.
    public func answerSpacing(_ answer: SpacingAnswer) -> KeyResponse {
        guard let word = pendingQuestion else {
            preconditionFailure("answerSpacing called with no question pending")
        }
        pendingQuestion = nil
        let asked = (pendingQuestionText, String(describing: answer))
        let response: KeyResponse
        switch answer {
        case .failed:
            response = keepAsTyped(word, asked: asked)
        case .respace, .undecided:
            response = settle(word, spacing: .respace, asked: asked)
        case .keepAsTyped:
            response = settle(word, spacing: .keepAsTyped, asked: asked)
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
            return endRunAtEnter()
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

    /// Space and Shift+Space step through the candidates when there is more than one; Escape
    /// restores what was typed.
    /// Returns nil for any other key.
    private func correct(_ correction: Correction, with key: RawKey) -> KeyResponse? {
        guard !key.command, !key.control, !key.option else { return nil }
        let onScreen = correction.shown + correction.suffix
        switch key.keyCode {
        case KeyCode.space where correction.candidates.count > 1:
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
            run.append(key.isSymbolLayer(at: position)
                ? .literal(Layout.qwerty.character(at: position, shift: true))
                : .stroke(position, shift: key.shift))
        } else if let character = key.printableCharacter {
            run.append(.literal(character))
        } else {
            run = Run()
        }
    }

    /// Ends the word at a Space: asks for the language of an ambiguous word, settles the rest.
    private func endWord() -> KeyResponse {
        let word = run
        run = Run()
        if asksLanguage, let question = planner.question(for: word) {
            heldKeys = []
            pendingQuestion = word
            switch question {
            case let .spacing(respaced):
                pendingQuestionText = "spacing: \(respaced)"
                return .askSpacing(SpacingQuestion(typed: word.screenText, respaced: respaced, textBefore: recentText))
            case let .language(ruleReading):
                pendingQuestionText = "language: \(ruleReading)"
                return .askLanguage(LanguageQuestion(
                    typed: word.screenText, ebiReading: word.reading(in: .ebi),
                    textBefore: recentText, ruleReading: ruleReading
                ))
            }
        }
        return settle(word)
    }

    /// Hands the word to azooKey, replaces it, or lets it pass, in `language` for its
    /// ambiguous parts. Keeps keys already held while a question was pending.
    private func settle(
        _ word: Run, preferring language: Language? = nil, spacing: Spacing? = nil,
        asked: (question: String?, answer: String?) = (nil, nil)
    ) -> KeyResponse {
        switch planner.plan(word, preferring: language, spacing: spacing) {
        case .pass:
            return keepAsTyped(word, asked: asked)
        case let .convert(pieces):
            if heldKeys == nil { heldKeys = [] }
            if let handOff = planner.handOff(for: word, preferring: language, spacing: spacing) {
                let reading = Self.reading(of: handOff.settled) + handOff.romaji
                remember(reading)
                record(word, asked: asked, outcome: "handed to azooKey: \(reading)")
                return .handOff(handOff)
            }
            remember(Self.reading(of: pieces))
            record(word, asked: asked, outcome: "replaced: \(Self.reading(of: pieces))")
            let replacement = Replacement(typed: word.screenText, pieces: pieces, suffix: " ")
            pendingReplacement = replacement
            // A Space conversion that could not go to azooKey (the word ends in English) is
            // committed as is; English that was only respaced can be undone with Escape
            pendingCorrectable = !pieces.contains { if case .romaji = $0 { true } else { false } }
            return .replace(replacement)
        }
    }

    /// The word stays as typed; the Space that ended it passes (or is typed back after a question).
    private func keepAsTyped(_ word: Run, asked: (question: String?, answer: String?)) -> KeyResponse {
        remember(word.screenText)
        record(word, asked: asked, outcome: "as typed")
        return .pass
    }

    private func record(_ word: Run, asked: (question: String?, answer: String?), outcome: String) {
        recordWord?(WordRecord(typed: word.screenText, question: asked.question, answer: asked.answer, outcome: outcome))
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

    /// Plans the run at Enter and starts a new one. A conversion suppresses Enter, is committed
    /// at once (never handed to azooKey) and can be stepped through afterwards.
    private func endRunAtEnter() -> KeyResponse {
        let decision = planner.plan(run)
        let word = run
        run = Run()
        switch decision {
        case .pass:
            if !word.screenText.isEmpty {
                record(word, asked: (nil, nil), outcome: "as typed")
            }
            return .pass
        case let .convert(pieces):
            heldKeys = []
            record(word, asked: (nil, nil), outcome: "replaced: \(Self.reading(of: pieces))")
            let replacement = Replacement(typed: word.screenText, pieces: pieces, suffix: "")
            pendingReplacement = replacement
            pendingCorrectable = true
            return .replace(replacement)
        }
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
