/// One evaluation example: the keys as they show in QWERTY, and the sentence the user meant.
public struct CorpusEntry: Equatable, Sendable {
    public var typed: String
    public var intended: String

    public init(typed: String, intended: String) {
        self.typed = typed
        self.intended = intended
    }
}

public enum Corpus {
    public enum ParseError: Error, Equatable {
        /// The line (counted from 1) does not hold exactly two tab-separated fields.
        case malformedLine(number: Int)
    }

    /// Reads "typed<TAB>intended" lines. Blank lines and lines starting with "#" are skipped.
    public static func parse(_ tsv: String) throws -> [CorpusEntry] {
        var entries: [CorpusEntry] = []
        for (index, line) in tsv.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if line.isEmpty || line.hasPrefix("#") { continue }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2 else {
                throw ParseError.malformedLine(number: index + 1)
            }
            entries.append(CorpusEntry(typed: String(fields[0]), intended: String(fields[1])))
        }
        return entries
    }
}
