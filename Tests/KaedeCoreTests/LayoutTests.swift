import Testing
@testable import KaedeCore

@Suite struct LayoutTests {
    @Test func qwertyReadsTheKeyPrintedOnIt() {
        #expect(Layout.qwerty.character(at: .a, shift: false) == "a")
        #expect(Layout.qwerty.character(at: .semicolon, shift: false) == ";")
    }

    @Test func ebiReadsEveryPositionAsTheEbiTable() {
        // CLAUDE.md 5.1, rows in QWERTY position order
        let read = KeyPosition.allCases.map { Layout.ebi.character(at: $0, shift: false) }
        #expect(String(read) == "ql,.;fwryp" + "aoeiuktnsh" + "zxcv/gdmjb")
    }

    @Test func shiftGivesUppercaseLetters() {
        #expect(Layout.qwerty.character(at: .a, shift: true) == "A")
        #expect(Layout.ebi.character(at: .j, shift: true) == "T")
    }

    @Test func shiftOnASymbolKeyGivesTheShiftedSymbolOfTheTargetKey() {
        #expect(Layout.qwerty.character(at: .semicolon, shift: true) == ":")
        #expect(Layout.qwerty.character(at: .comma, shift: true) == "<")
        #expect(Layout.qwerty.character(at: .period, shift: true) == ">")
        #expect(Layout.qwerty.character(at: .slash, shift: true) == "?")
        // Ebi types ? as Shift + the QWERTY B position
        #expect(Layout.ebi.character(at: .b, shift: true) == "?")
        #expect(Layout.ebi.character(at: .e, shift: true) == "<")
    }
}
