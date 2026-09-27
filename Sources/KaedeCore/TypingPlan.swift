/// A part of the text the input form puts into another app.
public enum TypingPiece: Equatable, Sendable {
    /// Characters typed by one key event.
    case text(String)
    /// A line break, typed as Shift+Enter so that chat apps and Claude Code do not send.
    case newline
}

public enum TypingPlanError: Error, Equatable {
    /// Tab and control characters would act as keys in the app (Tab completes in Claude Code).
    case unsupportedCharacter(Character)
    /// One character needs more UTF-16 units than a key event can carry.
    case characterTooLong(Character)
}

/// Splits the input form's text into what key events can type.
public enum TypingPlan {
    /// CGEventKeyboardSetUnicodeString takes at most 20 UTF-16 units per event.
    public static let maxUnitsPerPiece = 20

    /// Newlines of any kind, and runs of other characters no longer than `maxUnitsPerPiece`
    /// units, never splitting a character.
    public static func pieces(for text: String) throws -> [TypingPiece] {
        var pieces: [TypingPiece] = []
        var run = ""
        func endRun() {
            if !run.isEmpty {
                pieces.append(.text(run))
                run = ""
            }
        }
        for character in text {
            if lineBreaks.contains(character) {
                endRun()
                pieces.append(.newline)
                continue
            }
            if character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) {
                throw TypingPlanError.unsupportedCharacter(character)
            }
            let units = character.utf16.count
            guard units <= maxUnitsPerPiece else {
                throw TypingPlanError.characterTooLong(character)
            }
            if run.utf16.count + units > maxUnitsPerPiece {
                endRun()
            }
            run.append(character)
        }
        endRun()
        return pieces
    }

    /// NSTextView puts U+2028 for Shift+Enter; the others come with pasted text.
    private static let lineBreaks: Set<Character> = ["\n", "\r\n", "\r", "\u{2028}", "\u{2029}", "\u{85}"]
}
