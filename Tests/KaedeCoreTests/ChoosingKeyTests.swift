import Testing
@testable import KaedeCore

@Suite struct ChoosingKeyTests {
    private func action(_ keyCode: UInt16, _ modifiers: KeyCombo.Modifiers = [], _ characters: String = "") -> ChoosingAction? {
        ChoosingKey.action(keyCode: keyCode, modifiers: modifiers, characters: characters)
    }

    @Test func movesBetweenUnitsWithTheArrows() {
        #expect(action(123) == .move(-1))
        #expect(action(124) == .move(1))
    }

    @Test func movesAPhraseBorderWithShiftAndTheArrows() {
        #expect(action(123, .shift) == .resize(-1))
        #expect(action(124, .shift) == .resize(1))
    }

    @Test func stepsThroughCandidatesWithUpDownAndSpace() {
        #expect(action(125) == .step(1))
        #expect(action(126) == .step(-1))
        #expect(action(49) == .step(1))
        #expect(action(49, .shift) == .step(-1))
    }

    @Test func picksACandidateByItsNumber() {
        #expect(action(20, [], "3") == .pick(3))
        #expect(action(29, [], "0") == nil)
    }

    @Test func keepsTheChoicesWithReturnEnterAndTab() {
        #expect(action(36) == .keep)
        #expect(action(76) == .keep)
        #expect(action(48) == .keep)
    }

    @Test func cancelsWithEscapeAndBackspace() {
        #expect(action(53) == .cancel)
        #expect(action(51) == .cancel)
    }

    @Test func leavesOtherKeysToTheText() {
        #expect(action(0, [], "a") == nil)
        #expect(action(123, .command) == nil)
        #expect(action(8, .command, "c") == nil)
    }
}
