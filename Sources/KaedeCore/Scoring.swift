/// One converted example.
public struct EvaluationResult: Sendable {
    public var intended: String
    public var output: String
    public var duration: Duration

    public init(intended: String, output: String, duration: Duration) {
        self.intended = intended
        self.output = output
        self.duration = duration
    }
}

public struct EvaluationSummary: Sendable {
    public var exactMatches: Int
    public var total: Int
    /// Edits needed over all outputs, divided by all intended characters.
    public var characterErrorRate: Double
    public var medianLatency: Duration
    public var maxLatency: Duration
}

/// Measures how close conversions come to the sentences the user meant.
public enum Scoring {
    /// Levenshtein distance over characters (grapheme clusters).
    public static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        // previous[j]: distance between the first i-1 characters of a and the first j of b
        var previous = Array(0...b.count)
        for i in a.indices {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for j in b.indices.map({ $0 + 1 }) {
                let substitution = previous[j - 1] + (a[i] == b[j - 1] ? 0 : 1)
                current[j] = min(previous[j] + 1, current[j - 1] + 1, substitution)
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Summarizes a non-empty list of results.
    public static func summary(of results: [EvaluationResult]) -> EvaluationSummary {
        precondition(!results.isEmpty, "summary needs at least one result")
        let edits = results.map { editDistance($0.output, $0.intended) }.reduce(0, +)
        let intendedCharacters = results.map(\.intended.count).reduce(0, +)
        let durations = results.map(\.duration).sorted()
        return EvaluationSummary(
            exactMatches: results.filter { $0.output == $0.intended }.count,
            total: results.count,
            characterErrorRate: Double(edits) / Double(intendedCharacters),
            medianLatency: durations[(durations.count - 1) / 2],
            maxLatency: durations[durations.count - 1]
        )
    }
}
