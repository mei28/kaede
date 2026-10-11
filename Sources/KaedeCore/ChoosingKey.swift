/// What a key does while choosing conversions in the form.
public enum ChoosingAction: Equatable, Sendable {
    /// To the unit `delta` places away.
    case move(Int)
    /// Moves the border after the selected phrase by a character.
    case resize(Int)
    /// To the candidate `delta` places away.
    case step(Int)
    /// The numbered candidate, then on to the next unit.
    case pick(Int)
    /// Keeps the choices and goes back to writing.
    case keep
    /// Takes back the choices made since choosing began.
    case cancel
}

/// The keys of choosing, as in an input method.
public enum ChoosingKey {
    /// - Parameters:
    ///   - modifiers: only command, control, option and shift count; the function and keypad
    ///     marks macOS puts on arrow keys do not.
    ///   - characters: what the key types without modifiers, for the numbers.
    /// - Returns: nil for any other key, which ends choosing and goes on to the text: Backspace
    ///   deletes there, and the phrases chosen in a clause outlast the letters it takes.
    public static func action(keyCode: UInt16, modifiers: KeyCombo.Modifiers, characters: String) -> ChoosingAction? {
        guard modifiers.subtracting(.shift).isEmpty else { return nil }
        let shift = modifiers.contains(.shift)
        switch keyCode {
        case 123: return shift ? .resize(-1) : .move(-1)
        case 124: return shift ? .resize(1) : .move(1)
        case 125: return .step(1)
        case 126: return .step(-1)
        case 49: return .step(shift ? -1 : 1)
        // Return, Enter, Tab
        case 36, 76, 48: return .keep
        case 53: return .cancel
        default:
            guard !shift, let number = Int(characters), (1...9).contains(number) else { return nil }
            return .pick(number)
        }
    }
}
