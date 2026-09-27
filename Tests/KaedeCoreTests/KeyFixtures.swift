@testable import KaedeCore

extension RawKey {
    /// The key that types `character` on screen with the Roman source: one of the 30 layout
    /// keys (uppercase with Shift), Space, a digit or "-".
    static func typing(_ character: Character) -> RawKey {
        let lowered = Character(character.lowercased())
        if let position = KeyPosition.allCases.first(where: { $0.qwertyCharacter == lowered }) {
            return RawKey(keyCode: position.keyCode, character: character, shift: character != lowered)
        }
        let keyCodes: [Character: UInt16] = [" ": 49, "-": 27, "0": 29, "1": 18, "2": 19, "3": 20]
        return RawKey(keyCode: keyCodes[character]!, character: character)
    }

    static let enter = RawKey(keyCode: 36, character: "\r")
    static let backspace = RawKey(keyCode: 51, character: "\u{8}")
    static let tab = RawKey(keyCode: 48, character: "\t")
    static let escape = RawKey(keyCode: 53, character: "\u{1b}")
    static let leftArrow = RawKey(keyCode: 123, character: "\u{F702}")
    /// F5: a key whose character is private use.
    static let functionKey = RawKey(keyCode: 96, character: "\u{F708}")
}

extension SwitchEngine {
    /// Types `text` key by key at `instant` with the Roman source, and returns the questions asked.
    @discardableResult
    func type(_ text: String, at instant: ContinuousClock.Instant) -> [Question] {
        text.compactMap { handle(.typing($0), source: .roman, at: instant).1.question }
    }
}

extension DictionaryRule {
    /// Knows a few English words, so the tests read without the system word list.
    static let forTests = DictionaryRule(lexicon: EnglishLexicon(wordList: "the\nthink\nwater\n"))
}
