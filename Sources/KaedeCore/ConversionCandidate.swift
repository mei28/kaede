/// What a unit can become, and in which language it then counts.
public struct ConversionCandidate: Equatable, Sendable {
    public var text: String
    public var language: Language

    public init(_ text: String, _ language: Language) {
        self.text = text
        self.language = language
    }
}
