/// A word of the evaluation table: what was typed before it, its keys as they show on screen
/// with the Roman source, and what the word is.
public struct WordCase: Equatable, Sendable {
    public var textBefore: String
    public var keys: String
    public var answer: Answer

    public init(textBefore: String, keys: String, answer: Answer) {
        self.textBefore = textBefore
        self.keys = keys
        self.answer = answer
    }
}

public enum WordTableError: Error, Equatable {
    /// The line does not have exactly three tab-separated columns.
    case malformedLine(Int)
    /// The answer is not english, japanese_qwerty or japanese_ebi.
    case unknownAnswer(line: Int, String)
}

/// Reads `Evaluation/words.tsv`: `text before<TAB>keys<TAB>answer` per line; lines starting
/// with # and blank lines are skipped.
public enum WordTable {
    public static func parse(_ text: String) throws -> [WordCase] {
        var cases: [WordCase] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if line.isEmpty || line.hasPrefix("#") { continue }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count == 3, !columns[1].isEmpty else {
                throw WordTableError.malformedLine(index + 1)
            }
            guard let answer = Answer(rawValue: String(columns[2])), answer != .keep else {
                throw WordTableError.unknownAnswer(line: index + 1, String(columns[2]))
            }
            cases.append(WordCase(textBefore: String(columns[0]), keys: String(columns[1]), answer: answer))
        }
        return cases
    }
}
