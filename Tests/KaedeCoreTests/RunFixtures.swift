@testable import KaedeCore

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
