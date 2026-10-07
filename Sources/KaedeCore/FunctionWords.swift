/// Japanese words that follow another word, as typed in romaji: particles, with their kana, and
/// verb endings.
enum FunctionWords {
    static let particles: [String: String] = [
        "no": "の", "ga": "が", "wo": "を", "ni": "に", "de": "で", "to": "と", "ha": "は",
        "mo": "も", "wa": "わ", "he": "へ", "kara": "から", "made": "まで", "yori": "より",
    ]

    /// The longest first, so "made" is found before "de".
    static let particlesLongestFirst = particles.keys.sorted { ($0.count, $0) > ($1.count, $1) }

    static let verbEndings: Set<String> = ["site", "sita", "shita", "shite", "suru", "simasu", "shimasu"]

    /// Particles and verb endings, some of which are English words too (no, to, he, made, site).
    static let all = Set(particles.keys).union(verbEndings)
}
