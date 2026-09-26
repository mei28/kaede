/// Converts one romaji chunk (no spaces) into kana-kanji text.
public protocol KanaKanjiConverting {
    func convert(romaji: String) throws -> String
}
