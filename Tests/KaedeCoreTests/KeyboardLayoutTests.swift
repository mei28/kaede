import Testing
@testable import KaedeCore

@Suite struct KeyboardLayoutTests {
    @Test func readsAKeyAsTheLayoutPutsItThere() {
        let ebi = KeyboardLayout.ebi
        let read = ["j", ";", ",", ".", "/", "e", "r", "t", "b", "a"].map { ebi.read(Character($0)) }
        #expect(read == ["t", "h", "m", "j", "b", ",", ".", ";", "/", "a"])
    }

    @Test func readsTypedTextThroughTheLayout() {
        #expect(KeyboardLayout.ebi.read("jajsd/a") == "tatoeba")
        #expect(KeyboardLayout.ebi.read(";sk") == "hon")
    }

    @Test func readsACapitalAsTheLayoutsCapitalOrShiftedSymbol() {
        let ebi = KeyboardLayout.ebi
        #expect(ebi.read(Character("J")) == "T")
        #expect(ebi.read(Character("E")) == "<")
        #expect(ebi.read(Character("B")) == "?")
    }

    @Test func leavesOtherCharactersAsTyped() {
        #expect(KeyboardLayout.ebi.read("?-1:") == "?-1:")
    }

    @Test func takesRowsWithSpacesInThem() throws {
        let spaced = try KeyboardLayout(rows: ["q l , . ; f w r y p", "a o e i u k t n s h", "z x c v / g d m j b"])
        #expect(spaced == .ebi)
    }

    @Test func refusesRowsThatAreNotALayout() {
        #expect(throws: KeyboardLayoutError.rowCount(2)) {
            try KeyboardLayout(rows: ["ql,.;fwryp", "aoeiuktnsh"])
        }
        #expect(throws: KeyboardLayoutError.rowLength(row: 2, length: 9)) {
            try KeyboardLayout(rows: ["ql,.;fwryp", "aoeiuktns", "zxcv/gdmjb"])
        }
        #expect(throws: KeyboardLayoutError.notAKey("@", row: 1)) {
            try KeyboardLayout(rows: ["ql,.;fwry@", "aoeiuktnsh", "zxcv/gdmjb"])
        }
        #expect(throws: KeyboardLayoutError.repeated("q")) {
            try KeyboardLayout(rows: ["ql,.;fwryq", "aoeiuktnsh", "zxcv/gdmjb"])
        }
    }

    @Test func offersTheLayoutsOfTheUsersHammerspoon() {
        #expect(KeyboardLayout.presets.map(\.name) == ["Ebi", "Eucalyn", "大西", "Waddlier"])
        // The bottom rows of 大西 and Waddlier, the top of Eucalyn
        #expect(KeyboardLayout.oonishi.read("bn,./") == ";gmjb")
        #expect(KeyboardLayout.waddlier.read("bn,./") == "bgmj/")
        #expect(KeyboardLayout.eucalyn.read("yuio") == "mrdy")
    }

    @Test func readsNothingDifferentlyInQwerty() {
        #expect(KeyboardLayout.qwerty.isQwerty)
        #expect(!KeyboardLayout.ebi.isQwerty)
        #expect(KeyboardLayout.qwerty.read("jajsd/a") == "jajsd/a")
    }
}
