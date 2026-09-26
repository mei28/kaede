/// Converts one romaji chunk (no spaces) into kana-kanji text.
public protocol KanaKanjiConverting {
    func convert(romaji: String) throws -> String
    /// Up to `limit` distinct conversions, best first; the first equals `convert(romaji:)`.
    func candidates(romaji: String, limit: Int) throws -> [String]
}
