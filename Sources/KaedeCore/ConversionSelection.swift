/// Choosing conversions in the form: which unit is selected and which of its candidates shows.
///
/// The form converts again after each choice, so the selection follows its unit through new
/// units by the unit's kind and line rather than by its place.
public struct ConversionSelection: Equatable, Sendable {
    public private(set) var units: [ConversionUnit]
    public private(set) var selected: Int
    /// The selected unit's candidates, empty until shown.
    public private(set) var candidates: [ConversionCandidate] = []
    /// Which candidate shows, or nil when the unit shows none of them.
    public private(set) var candidateIndex: Int?
    /// What was chosen before, for cancelling.
    public let choicesAtStart: ConversionChoices

    /// Selects the first unit of the line, or the last before it; nil when nothing can be chosen.
    public init?(units: [ConversionUnit], line: Int, choices: ConversionChoices) {
        guard !units.isEmpty else { return nil }
        self.units = units
        selected = units.firstIndex { $0.line == line } ?? units.lastIndex { $0.line < line } ?? 0
        choicesAtStart = choices
    }

    public var selectedUnit: ConversionUnit {
        units[selected]
    }

    /// Selects the unit `delta` places away; false past either end.
    @discardableResult
    public mutating func move(by delta: Int) -> Bool {
        guard units.indices.contains(selected + delta) else { return false }
        selected += delta
        candidates = []
        candidateIndex = nil
        return true
    }

    public mutating func show(candidates: [ConversionCandidate]) {
        self.candidates = candidates
        candidateIndex = candidates.firstIndex { $0.text == selectedUnit.text }
    }

    /// The candidate `delta` places away, going round at the ends; nil before any are shown.
    public mutating func stepCandidate(by delta: Int) -> ConversionCandidate? {
        guard !candidates.isEmpty else { return nil }
        // From none shown, down starts at the first and up at the last
        let current = candidateIndex ?? (delta > 0 ? -1 : 0)
        let next = ((current + delta) % candidates.count + candidates.count) % candidates.count
        candidateIndex = next
        return candidates[next]
    }

    /// The candidate numbered from 1, or nil when there is no such number.
    public mutating func pickCandidate(number: Int) -> ConversionCandidate? {
        guard (1...candidates.count).contains(number) else { return nil }
        candidateIndex = number - 1
        return candidates[number - 1]
    }

    /// `choices` with `candidate` chosen for the selected unit: its phrase in the clause's
    /// phrases, or Japanese for English (none when the English as typed is chosen back).
    public func choices(_ choices: ConversionChoices, choosing candidate: ConversionCandidate) -> ConversionChoices {
        var choices = choices
        switch selectedUnit.kind {
        case let .bunsetsu(clause, index):
            var phrases = phrasesOfSelectedClause()
            phrases[index].text = candidate.text
            phrases[index].language = candidate.language
            phrases[index].isChosen = true
            choices.clauses[clause] = phrases
        case let .english(typed):
            choices.english[typed] = candidate == ConversionCandidate(typed, .english) ? nil : candidate
        }
        return choices
    }

    /// The phrases of the selected unit's clause as they show, or nil for English.
    public var clausePhrases: [Bunsetsu]? {
        guard case .bunsetsu = selectedUnit.kind else { return nil }
        return phrasesOfSelectedClause()
    }

    /// Where the selected phrase's reading sits in its clause's reading, in characters; nil for
    /// English.
    public var selectedPhraseReadingRange: Range<Int>? {
        guard case let .bunsetsu(_, index) = selectedUnit.kind else { return nil }
        let phrases = phrasesOfSelectedClause()
        let start = phrases[..<index].map(\.reading.count).reduce(0, +)
        return start..<(start + phrases[index].reading.count)
    }

    /// Takes the units of the text converted again and selects the same unit in them; false when
    /// it is gone. The candidates stay while the unit reads the same.
    @discardableResult
    public mutating func update(units: [ConversionUnit]) -> Bool {
        let previous = selectedUnit
        guard let index = units.firstIndex(where: { $0.kind == previous.kind && $0.line == previous.line }) else {
            return false
        }
        self.units = units
        selected = index
        if units[index].reading != previous.reading {
            candidates = []
            candidateIndex = nil
        }
        return true
    }

    /// The units next to the selected one that share its clause and line, in order.
    private func phrasesOfSelectedClause() -> [Bunsetsu] {
        guard case let .bunsetsu(clause, _) = selectedUnit.kind else {
            preconditionFailure("only a phrase has a clause")
        }
        func sameClause(_ unit: ConversionUnit) -> Bool {
            guard case .bunsetsu(clause, _) = unit.kind else { return false }
            return unit.line == selectedUnit.line
        }
        var first = selected
        while first > 0, sameClause(units[first - 1]) {
            first -= 1
        }
        var last = selected
        while last + 1 < units.count, sameClause(units[last + 1]) {
            last += 1
        }
        return units[first...last].map {
            Bunsetsu(reading: $0.reading, text: $0.text, language: $0.language, letterCount: $0.letterCount, isChosen: $0.isChosen)
        }
    }
}
