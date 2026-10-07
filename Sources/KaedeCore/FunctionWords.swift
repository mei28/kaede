/// Japanese words that follow another word, as typed in romaji, with their kana: particles and
/// verb endings.
enum FunctionWords {
    static let particles: [String: String] = [
        "no": "の", "ga": "が", "wo": "を", "ni": "に", "de": "で", "to": "と", "ha": "は",
        "mo": "も", "wa": "わ", "he": "へ", "kara": "から", "made": "まで", "yori": "より",
    ]

    /// The longest first, so "made" is found before "de".
    static let particlesLongestFirst = particles.keys.sorted { ($0.count, $0) > ($1.count, $1) }

    static let verbEndings: [String: String] = [
        "site": "して", "sita": "した", "shita": "した", "shite": "して", "suru": "する",
        "simasu": "します", "shimasu": "します",
    ]

    /// Particles and verb endings, some of which are English words too (no, to, he, made, site).
    static let all = Set(particles.keys).union(verbEndings.keys)

    /// The kana of a particle or verb ending, or nil for other romaji.
    static func kana(of romaji: String) -> String? {
        particles[romaji] ?? verbEndings[romaji]
    }
}
