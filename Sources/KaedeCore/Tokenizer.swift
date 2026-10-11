public enum Language: Sendable {
    case english
    case japanese
}

/// A piece of a typed line, as the converter reads it.
public enum Token: Equatable, Sendable {
    /// Letters, `, . ; /` and "-" after a letter, as typed: a layout puts letters on , . ; / and
    /// symbols on letters, so only reading the run decides which are which.
    case keys(String)
    /// ASCII letters, with "-" after a letter (ra-men, e-mail).
    case letters(String)
    /// Digits, with "," or "." between two digits (1,000, 3.14).
    case digits(String)
    /// , . ? ! after a word.
    case punctuation(Character)
    /// A bracket or quote around words, or : ; after them, kept as typed.
    case mark(String)
    /// Kept as typed: paths, file names, addresses and contractions (English), or text typed
    /// with an input method (Japanese).
    case verbatim(String, Language)
}

public struct TypedToken: Equatable, Sendable {
    public var token: Token
    /// Whether a space came before it as typed.
    public var spaceBefore: Bool
}

/// Cuts a typed line into tokens.
public enum Tokenizer {
    public static func tokens(of line: Substring) -> [TypedToken] {
        line.split(whereSeparator: \.isWhitespace).flatMap { chunk in
            var tokens = Self.tokens(ofChunk: chunk)
            if !tokens.isEmpty, chunk.startIndex != line.startIndex {
                tokens[0].spaceBefore = true
            }
            return tokens
        }
    }

    /// The tokens of text typed without a space.
    private static func tokens(ofChunk chunk: Substring) -> [TypedToken] {
        guard chunk.allSatisfy(\.isASCII) else {
            let language: Language = chunk.contains(where: isJapanese) ? .japanese : .english
            return [TypedToken(token: .verbatim(String(chunk), language), spaceBefore: false)]
        }
        var core = chunk
        var leading: [Token] = []
        while let first = core.first, openingMarks.contains(first) {
            leading.append(.mark(String(first)))
            core.removeFirst()
        }
        var trailing: [Token] = []
        while let last = core.last {
            if closingMarks.contains(last) {
                trailing.insert(.mark(String(last)), at: 0)
            } else if punctuation.contains(last) {
                trailing.insert(.punctuation(last), at: 0)
            } else {
                break
            }
            core.removeLast()
        }
        return (leading + tokens(ofCore: core) + trailing).map { TypedToken(token: $0, spaceBefore: false) }
    }

    /// Runs of keys, numbers and the marks between them; anything else keeps the whole as typed.
    private static func tokens(ofCore core: Substring) -> [Token] {
        guard !core.isEmpty else { return [] }
        let verbatim = [Token.verbatim(String(core), .english)]
        let characters = Array(core)
        var tokens: [Token] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if isKey(character) {
                var end = index + 1
                while end < characters.count, isKey(characters[end]) || (characters[end] == "-" && characters[end - 1].isLetter) {
                    end += 1
                }
                tokens.append(.keys(String(characters[index..<end])))
                index = end
            } else if character.isNumber {
                var end = index + 1
                while end < characters.count, characters[end].isNumber
                    || (",.".contains(characters[end]) && end + 1 < characters.count && characters[end + 1].isNumber)
                {
                    end += 1
                }
                tokens.append(.digits(String(characters[index..<end])))
                index = end
            } else if "?!".contains(character) {
                tokens.append(.punctuation(character))
                index += 1
            } else {
                // Paths, addresses, a "-" after no letter
                return verbatim
            }
        }
        return tokens
    }

    /// The characters a layout may read differently: letters and the four keys , . ; /.
    private static func isKey(_ character: Character) -> Bool {
        character.isLetter || ",.;/".contains(character)
    }

    private static let openingMarks: Set<Character> = ["(", "[", "{", "\"", "'"]
    private static let closingMarks: Set<Character> = [")", "]", "}", "\"", "'", ":", ";"]
    private static let punctuation: Set<Character> = [",", ".", "?", "!"]

    /// Kana, kanji and Japanese punctuation.
    private static func isJapanese(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0x3000...0x30FF).contains(scalar.value) || (0x3400...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value) || (0xFF00...0xFFEF).contains(scalar.value)
        }
    }
}
