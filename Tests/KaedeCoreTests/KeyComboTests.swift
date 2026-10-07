import Testing
@testable import KaedeCore

@Suite struct KeyComboTests {
    @Test func readsModifiersAndOneKey() throws {
        let open = try KeyCombo(parsing: "ctrl+alt+k")
        #expect(open == KeyCombo(keyCode: KeyPosition.k.keyCode, modifiers: [.control, .option]))
        #expect(open.description == "ctrl+alt+k")
        #expect(try KeyCombo(parsing: "cmd+enter") == KeyCombo(keyCode: 36, modifiers: [.command]))
    }

    @Test func toleratesCaseSpacesAndOtherNamesForTheSameKeys() throws {
        #expect(try KeyCombo(parsing: "Command + Return") == KeyCombo(parsing: "cmd+enter"))
        #expect(try KeyCombo(parsing: "control+option+K") == KeyCombo(parsing: "ctrl+alt+k"))
    }

    @Test(arguments: [("ctrl+1", UInt16(0x12)), ("ctrl+0", 0x1D), ("ctrl+space", 49), ("ctrl+tab", 48), ("ctrl+;", 0x29), ("shift+cmd+/", 0x2C)])
    func readsDigitsSpaceTabAndSymbolKeys(text: String, keyCode: UInt16) throws {
        #expect(try KeyCombo(parsing: text).keyCode == keyCode)
    }

    @Test func failsOnWhatItCannotRead() {
        #expect(throws: KeyComboError.noKey("")) { try KeyCombo(parsing: "") }
        #expect(throws: KeyComboError.noKey("ctrl+alt")) { try KeyCombo(parsing: "ctrl+alt") }
        #expect(throws: KeyComboError.twoKeys("ctrl+k+j")) { try KeyCombo(parsing: "ctrl+k+j") }
        #expect(throws: KeyComboError.unknownPart("hyper")) { try KeyCombo(parsing: "hyper+k") }
        #expect(throws: KeyComboError.unknownPart("ü")) { try KeyCombo(parsing: "ctrl+ü") }
    }

    @Test(arguments: [("ctrl+alt+k", "⌃⌥K"), ("cmd+enter", "⌘↩"), ("cmd+shift+/", "⇧⌘/"), ("ctrl+space", "⌃Space"), ("alt+tab", "⌥⇥")])
    func showsItsKeysAsTheMenusDo(text: String, symbols: String) throws {
        // Control, Option, Shift, Command, then the key, as macOS menus list them
        #expect(try KeyCombo(parsing: text).symbols == symbols)
    }

    @Test func supportsOnlyTheKeysItCanName() {
        #expect(KeyCombo.supports(keyCode: KeyPosition.k.keyCode))
        #expect(KeyCombo.supports(keyCode: 36))
        #expect(!KeyCombo.supports(keyCode: 96))  // F5
        #expect(!KeyCombo.supports(keyCode: 53))  // Escape
    }

    @Test func matchesItsKeyWithExactlyItsModifiers() throws {
        let insert = try KeyCombo(parsing: "cmd+enter")
        #expect(insert.matches(keyCode: 36, modifiers: [.command]))
        #expect(!insert.matches(keyCode: 36, modifiers: [.command, .shift]))
        #expect(!insert.matches(keyCode: 36, modifiers: []))
        #expect(!insert.matches(keyCode: 76, modifiers: [.command]))
    }
}

@Suite struct FormKeysTests {
    private func keys(_ open: String, _ insert: String) throws -> FormKeys {
        try FormKeys(open: KeyCombo(parsing: open), insert: KeyCombo(parsing: insert))
    }

    @Test func theDefaultsAreValid() throws {
        #expect(try keys(FormKeys.defaultOpen, FormKeys.defaultInsert).open.description == "ctrl+alt+k")
    }

    @Test func openingNeedsControlOrCommand() throws {
        // macOS 15 refuses hot keys with only Option or Shift
        #expect(throws: FormKeysError.openNeedsControlOrCommand) { try keys("alt+k", "cmd+enter") }
        _ = try keys("cmd+shift+k", "cmd+enter")
    }

    @Test func theKeysMustDiffer() {
        #expect(throws: FormKeysError.sameKeys) { try keys("ctrl+alt+k", "ctrl+alt+k") }
    }

    @Test func enterAloneCannotInsert() {
        // Enter makes new lines in the form
        #expect(throws: FormKeysError.plainEnterInserts) { try keys("ctrl+alt+k", "enter") }
    }
}
