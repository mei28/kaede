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
}

/// Tracks the run and decides, per event, what the tap does. Runs on the tap's thread only.
public final class KeyEngine {
    private let planner: EnterPlanner
    private(set) var run = Run()
    /// Keys pressed while a replacement is being typed, or nil when none is in progress.
    /// Letting them through would race the replacement: a second Enter could send the half-replaced text.
    private var heldKeys: [RawKey]?

    public init(planner: EnterPlanner) {
        self.planner = planner
    }

    /// The caret may have moved: a click or a switch to another app.
    public func discardRun() {
        run = Run()
    }

    public func handle(_ key: RawKey) -> KeyResponse {
        if key.isKaedeEvent {
            return .pass
        }
        if heldKeys != nil {
            heldKeys?.append(key)
            return .suppress
        }
        if KeyCode.enter.contains(key.keyCode) {
            return handleEnter()
        }
        record(key)
        return .pass
    }

    /// Ends the replacement and returns the held keys, in the order they were pressed,
    /// for the caller to post again as fresh input.
    public func finishReplacement() -> [RawKey] {
        guard let keys = heldKeys else {
            preconditionFailure("finishReplacement called with no replacement in progress")
        }
        heldKeys = nil
        return keys
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

    private func handleEnter() -> KeyResponse {
        let decision = planner.plan(run)
        let deleteCount = run.screenText.count
        run = Run()
        switch decision {
        case .pass:
            return .pass
        case let .convert(pieces):
            heldKeys = []
            return .replace(Replacement(deleteCount: deleteCount, pieces: pieces))
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
