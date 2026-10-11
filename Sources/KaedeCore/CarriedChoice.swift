/// Keeps the phrases the user chose in a clause once the clause is typed differently.
///
/// Choices are found by the clause's romaji, so a letter deleted or added leaves the clause's own
/// choice behind. A chosen phrase whose letters did not change stays as chosen; the letters
/// around the kept phrases are converted again, those of phrases azooKey wrote included, so they
/// read along with the letters added.
enum CarriedChoice {
    /// The phrases for `clause` from the chosen clause that keeps the most of its letters, or nil
    /// when no chosen clause keeps more than half its letters and a chosen phrase whole.
    /// - Parameters:
    ///   - chosen: the phrases chosen for clauses, by the clauses' romaji.
    ///   - convert: converts letters around the kept phrases.
    static func phrases(for clause: String, from chosen: [String: [Bunsetsu]], convert: (String) throws -> [Bunsetsu]) rethrows -> [Bunsetsu]? {
        let letters = Array(clause)
        // Most letters kept first; the smaller romaji when as many, so the same text converts the same
        let carries = chosen.compactMap { previous, phrases in
            Carry(from: Array(previous), phrases: phrases, to: letters).map { (previous, $0) }
        }
        guard let carry = carries.min(by: { ($1.1.unchanged, $0.0) < ($0.1.unchanged, $1.0) })?.1 else {
            return nil
        }
        var phrases: [Bunsetsu] = []
        var position = 0
        for (range, phrase) in carry.kept {
            if position < range.lowerBound {
                phrases += try convert(String(letters[position..<range.lowerBound]))
            }
            phrases.append(phrase)
            position = range.upperBound
        }
        if position < letters.count {
            phrases += try convert(String(letters[position...]))
        }
        return phrases
    }
}

/// The chosen phrases of a clause that a clause typed differently keeps, where they now sit.
private struct Carry {
    /// Letters the same at the start and at the end.
    let unchanged: Int
    /// In order, with their letters in the new clause.
    let kept: [(Range<Int>, Bunsetsu)]

    /// Nil when the new clause keeps half the letters or fewer: it was typed anew, not changed.
    init?(from previous: [Character], phrases: [Bunsetsu], to letters: [Character]) {
        let prefix = zip(previous, letters).prefix { $0 == $1 }.count
        let suffix = zip(previous[prefix...].reversed(), letters[prefix...].reversed()).prefix { $0 == $1 }.count
        unchanged = prefix + suffix
        guard unchanged * 2 > previous.count else { return nil }
        let shift = letters.count - previous.count
        var kept: [Int: (Range<Int>, Bunsetsu)] = [:]
        // Each phrase's letters, counted from whichever end they are known from: a count that is
        // not known hides the places past it
        var start = 0
        for (index, phrase) in phrases.enumerated() {
            guard let count = phrase.letterCount else { break }
            if phrase.isChosen, start + count <= prefix {
                kept[index] = (start..<(start + count), phrase)
            }
            start += count
        }
        var end = previous.count
        for (index, phrase) in phrases.enumerated().reversed() {
            guard let count = phrase.letterCount else { break }
            if phrase.isChosen, end - count >= previous.count - suffix {
                kept[index] = ((end - count + shift)..<(end + shift), phrase)
            }
            end -= count
        }
        guard !kept.isEmpty else { return nil }
        self.kept = kept.sorted { $0.key < $1.key }.map(\.value)
    }
}
