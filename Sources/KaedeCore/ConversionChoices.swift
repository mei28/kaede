/// Conversions the user chose in the form, in place of the first candidates.
public struct ConversionChoices: Equatable, Sendable {
    /// The phrases chosen for a clause, by the clause's romaji. Typing the clause differently
    /// leaves the choice behind.
    public var clauses: [String: [Bunsetsu]] = [:]
    /// Japanese chosen for English words, by the words as typed (sake → 酒).
    public var english: [String: String] = [:]

    public init() {}
}
