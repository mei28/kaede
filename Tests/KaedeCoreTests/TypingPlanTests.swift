import Testing
@testable import KaedeCore

@Suite struct TypingPlanTests {
    @Test func textWithoutNewlinesIsOnePiece() throws {
        #expect(try TypingPlan.pieces(for: "今日は hello") == [.text("今日は hello")])
        #expect(try TypingPlan.pieces(for: "") == [])
    }

    @Test(arguments: ["\n", "\r\n", "\r", "\u{2028}", "\u{2029}", "\u{85}"])
    func eachKindOfLineBreakBecomesANewline(separator: String) throws {
        #expect(try TypingPlan.pieces(for: "a" + separator + "b") == [.text("a"), .newline, .text("b")])
    }

    @Test func emptyLinesKeepTheirNewlines() throws {
        #expect(try TypingPlan.pieces(for: "\na\n\nb\n") == [.newline, .text("a"), .newline, .newline, .text("b"), .newline])
    }

    @Test func longTextIsCutEveryTwentyUTF16Units() throws {
        let text = String(repeating: "x", count: 45)
        #expect(try TypingPlan.pieces(for: text) == [
            .text(String(repeating: "x", count: 20)), .text(String(repeating: "x", count: 20)), .text("xxxxx"),
        ])
    }

    @Test func aCharacterIsNeverSplitAcrossPieces() throws {
        // 😀 takes two UTF-16 units and would cross the 20th
        let text = String(repeating: "a", count: 19) + "😀"
        #expect(try TypingPlan.pieces(for: text) == [.text(String(repeating: "a", count: 19)), .text("😀")])
    }

    @Test func tabsAndOtherControlCharactersAreRefused() {
        // Tab completes in Claude Code and moves the focus in browsers
        #expect(throws: TypingPlanError.unsupportedCharacter("\t")) { try TypingPlan.pieces(for: "a\tb") }
        #expect(throws: TypingPlanError.unsupportedCharacter("\u{1b}")) { try TypingPlan.pieces(for: "a\u{1b}") }
    }

    @Test func aCharacterTooLongForOneEventIsRefused() {
        let stacked = Character("e" + String(repeating: "\u{301}", count: 25))
        #expect(throws: TypingPlanError.characterTooLong(stacked)) { try TypingPlan.pieces(for: String(stacked)) }
    }
}
