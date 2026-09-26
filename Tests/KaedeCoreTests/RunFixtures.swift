@testable import KaedeCore

extension Run {
    /// Builds a run from what the keys show in QWERTY: layout keys become strokes, the rest literals.
    init(typing qwertyText: String) {
        self.init()
        for character in qwertyText {
            let lowered = Character(character.lowercased())
            if let position = KeyPosition.allCases.first(where: { $0.qwertyCharacter == lowered }) {
                append(.stroke(position, shift: character != lowered))
            } else {
                append(.literal(character))
            }
        }
    }
}

extension KeyEngine {
    /// Presses the keys that show `qwertyText` on screen: layout keys and Space.
    func type(_ qwertyText: String) {
        for character in qwertyText {
            let lowered = Character(character.lowercased())
            if character == " " {
                _ = handle(RawKey(keyCode: 49, character: " "))
            } else {
                let position = KeyPosition.allCases.first { $0.qwertyCharacter == lowered }!
                _ = handle(RawKey(keyCode: position.keyCode, character: character, shift: character != lowered))
            }
        }
    }
}

extension RawKey {
    static let enter = RawKey(keyCode: 36, character: "\r")
}
