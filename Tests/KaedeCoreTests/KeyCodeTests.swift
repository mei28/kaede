import Testing
@testable import KaedeCore

@Suite struct KeyCodeTests {
    @Test func keyCodesOfTheThirtyKeysMapToTheirPositions() {
        // CLAUDE.md 5.1, in QWERTY position order
        let keyCodes: [UInt16] = [
            0x0c, 0x0d, 0x0e, 0x0f, 0x11, 0x10, 0x20, 0x22, 0x1f, 0x23,
            0x00, 0x01, 0x02, 0x03, 0x05, 0x04, 0x26, 0x28, 0x25, 0x29,
            0x06, 0x07, 0x08, 0x09, 0x0b, 0x2d, 0x2e, 0x2b, 0x2f, 0x2c,
        ]
        #expect(keyCodes.map { KeyPosition(keyCode: $0) } == KeyPosition.allCases)
    }

    @Test func otherKeyCodesMapToNoPosition() {
        #expect(KeyPosition(keyCode: 49) == nil)  // Space
        #expect(KeyPosition(keyCode: 36) == nil)  // Return
        #expect(KeyPosition(keyCode: 27) == nil)  // -
    }
}
