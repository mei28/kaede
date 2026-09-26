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
    /// Keys azooKey uses on the word it holds: step through candidates, move, edit, cancel.
    static let azooKeysOwn: Set<UInt16> = [space, backspace, escape, 123, 124, 125, 126]
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
    /// Suppress the event, commit the word azooKey holds, switch back to English, and type
    /// `replay` again (nil for Enter, which only commits).
    case settle(replay: RawKey?)
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
    /// Whether azooKey holds a handed-off word; its own keys go to it until the word settles.
    public private(set) var isWithAzooKey = false
    /// The last conversion, while the user can still step through its candidates.
    private var correction: Correction?

    public init(planner: EnterPlanner) {
        self.planner = planner
    }

    /// The caret may have moved: a click or a switch to another app. Ends correcting too.
    public func discardRun() {
        run = Run()
        correction = nil
        isWithAzooKey = false
    }

    public func handle(_ key: RawKey) -> KeyResponse {
        if key.isKaedeEvent {
            return .pass
        }
        if heldKeys != nil {
            heldKeys?.append(key)
            return .suppress
        }
        if isWithAzooKey {
            if KeyCode.azooKeysOwn.contains(key.keyCode), !key.command, !key.control, !key.option {
                return .pass
            }
            isWithAzooKey = false
            heldKeys = []
            return .settle(replay: KeyCode.enter.contains(key.keyCode) ? nil : key)
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
            return endRun(suffix: "", handsOffToAzooKey: false)
        }
        if key.keyCode == KeyCode.space, !key.command, !key.control, !key.option {
            // Words never share a segment across a space, so the word before it can convert now.
            // This is the one place that decides when Japanese goes to azooKey.
            return endRun(suffix: " ", handsOffToAzooKey: true)
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

    /// Ends a hand-off and returns the keys held meanwhile. When switching to azooKey worked,
    /// azooKey holds the word until a key other than its own settles it.
    public func finishHandOff(succeeded: Bool) -> [RawKey] {
        isWithAzooKey = succeeded
        return releaseHeldKeys()
    }

    /// Ends settling a word in azooKey (the input source is English again) and returns the
    /// keys held meanwhile.
    public func finishSettle() -> [RawKey] {
        releaseHeldKeys()
    }

    /// The input source left azooKey by other means (Hammerspoon on Escape, the user), so
    /// azooKey no longer holds a handed-off word.
    public func azooKeyWasLeft() {
        isWithAzooKey = false
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
            run = Run()
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
