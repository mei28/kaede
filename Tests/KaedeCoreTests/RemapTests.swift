import Testing
@testable import KaedeCore

@Suite struct RemapTests {
    private func key(_ position: KeyPosition, shift: Bool = false, rightShift: Bool = false, command: Bool = false) -> RawKey {
        RawKey(keyCode: position.keyCode, character: nil, shift: shift || rightShift, rightShift: rightShift, command: command)
    }

    @Test func ebiSendsTheKeyItsLayoutPutsAtThePosition() {
        #expect(Remap.keyCode(for: key(.j), in: .ebi) == KeyPosition.t.keyCode)
        #expect(Remap.keyCode(for: key(.e), in: .ebi) == KeyPosition.comma.keyCode)
        // Ebi keeps a where QWERTY has it: nothing to change
        #expect(Remap.keyCode(for: key(.a), in: .ebi) == nil)
    }

    @Test func shiftIsRemappedButShortcutsAreNot() {
        #expect(Remap.keyCode(for: key(.j, shift: true), in: .ebi) == KeyPosition.t.keyCode)
        #expect(Remap.keyCode(for: key(.j, command: true), in: .ebi) == nil)
    }

    @Test func theSymbolLayerKeepsItsSymbols() {
        // Right Shift + / is ? from the custom keyboard's symbol layer
        #expect(Remap.keyCode(for: key(.slash, rightShift: true), in: .ebi) == nil)
        #expect(Remap.keyCode(for: key(.j, rightShift: true), in: .ebi) == KeyPosition.t.keyCode)
    }

    @Test func keysOutsideTheLayoutAndQwertyAreLeftAlone() {
        #expect(Remap.keyCode(for: RawKey(keyCode: 49, character: " "), in: .ebi) == nil)
        for position in KeyPosition.allCases {
            #expect(Remap.keyCode(for: key(position), in: .qwerty) == nil)
        }
    }
}
