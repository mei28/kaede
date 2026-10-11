/// Reads a run of keys as QWERTY typed it: letters, with , and . between them as punctuation.
enum KeyRun {
    /// The run's letters and punctuation, or the whole run as typed English when it holds ; or /,
    /// or a period that does not sit between romaji (main.swift, node.js).
    static func qwertyTokens(_ run: String) -> [Token] {
        let verbatim = [Token.verbatim(run, .english)]
        guard !run.contains(where: { ";/".contains($0) }) else { return verbatim }
        var tokens: [Token] = []
        var letters = ""
        for character in run {
            if ",.".contains(character) {
                if !letters.isEmpty {
                    tokens.append(.letters(letters))
                    letters = ""
                }
                tokens.append(.punctuation(character))
            } else {
                letters.append(character)
            }
        }
        if !letters.isEmpty {
            tokens.append(.letters(letters))
        }
        return periodsSitBetweenRomaji(tokens) ? tokens : verbatim
    }

    /// A period inside a word ends a sentence only between romaji (desu.kyouha); between other
    /// letters it belongs to a name (main.swift, node.js).
    private static func periodsSitBetweenRomaji(_ tokens: [Token]) -> Bool {
        tokens.indices.allSatisfy { index in
            guard tokens[index] == .punctuation(".") else { return true }
            guard index > 0, index + 1 < tokens.count,
                  case let .letters(before) = tokens[index - 1],
                  case let .letters(after) = tokens[index + 1]
            else { return false }
            return RomajiParser.isPlainRomaji(before) && RomajiParser.isPlainRomaji(after)
        }
    }
}
