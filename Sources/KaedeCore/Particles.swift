/// Japanese particles as typed in romaji, which follow a word, with their kana.
enum Particles {
    static let kana: [String: String] = [
        "no": "の", "ga": "が", "wo": "を", "ni": "に", "de": "で", "to": "と", "ha": "は",
        "mo": "も", "wa": "わ", "he": "へ", "kara": "から", "made": "まで", "yori": "より",
    ]

    /// The longest first, so "made" is found before "de".
    static let romaji = kana.keys.sorted { ($0.count, $0) > ($1.count, $1) }
}
