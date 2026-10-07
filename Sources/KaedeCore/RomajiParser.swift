/// Decides whether typed letters read as romaji.
public enum RomajiParser {
    /// Whether the letters read as whole plain syllables, as an IME would turn them into kana
    /// with nothing left over. A "-" after a syllable reads as ー.
    public static func isPlainRomaji(_ letters: some StringProtocol) -> Bool {
        let characters = Array(letters)
        return !characters.isEmpty && plainReachable(characters)[characters.count]
    }

    /// Which positions whole plain syllables (and ー after one) can reach from the start.
    private static func plainReachable(_ characters: [Character]) -> [Bool] {
        var reachable = Array(repeating: false, count: characters.count + 1)
        reachable[0] = true
        for start in characters.indices where reachable[start] {
            for end in syllableEnds(in: characters, from: start, plain: true) {
                reachable[end] = true
            }
            if start > 0, characters[start] == "-" {
                reachable[start + 1] = true
            }
        }
        return reachable
    }

    /// The positions where a syllable starting at `start` can end, shortest first.
    /// A sokuon (the first of a doubled consonant) counts as a syllable of its own.
    static func syllableEnds(in characters: [Character], from start: Int, plain: Bool = false) -> [Int] {
        let smallKanaPrefixes: Set<Character> = ["x", "l"]
        var ends: [Int] = []
        if isSokuon(characters, at: start), !(plain && smallKanaPrefixes.contains(characters[start])) {
            ends.append(start + 1)
        }
        for length in 1...maxSyllableLength where start + length <= characters.count {
            let syllable = String(characters[start..<start + length])
            if syllables.contains(syllable), !(plain && smallKanaPrefixes.contains(characters[start])) {
                ends.append(start + length)
            }
        }
        return ends
    }

    /// A consonant typed twice gives っ for the first one ("kitte", "macchi"); "nn" is ん instead.
    private static func isSokuon(_ characters: [Character], at index: Int) -> Bool {
        let character = characters[index]
        return index + 1 < characters.count
            && characters[index + 1] == character
            && character.isLetter && character != "n"
            && !vowels.contains(String(character))
    }

    private static let vowels = ["a", "i", "u", "e", "o"]

    private static let syllables: Set<String> = {
        // A lone "n" is ん. Letting it split "na" as ん+あ only changes the kana, never whether
        // the letters are readable, so it needs no lookahead here.
        var table = Set(vowels + ["n", "nn"])
        // Read as 、 and 。
        table.formUnion([",", "."])
        let plain = ["k", "s", "t", "n", "h", "m", "y", "r", "w", "g", "z", "d", "b", "p"]
        // Hepburn spellings, where each consonant takes every vowel as IMEs accept (sha, che, tsa, fo)
        let hepburn = ["sh", "ch", "ts", "j", "f"]
        // Consonants that form contracted syllables with y (kya, sya, tyo, cyu, jya)
        let glided = ["k", "s", "t", "n", "h", "m", "r", "g", "z", "d", "b", "p", "c", "j"]
        for consonant in plain + hepburn {
            for vowel in vowels {
                table.insert(consonant + vowel)
            }
        }
        for consonant in glided {
            for vowel in vowels {
                table.insert(consonant + "y" + vowel)
            }
        }
        // Small kana: x or l before a vowel, tu, or a y-syllable (xa, ltu, xyo)
        for prefix in ["x", "l"] {
            for vowel in vowels {
                table.insert(prefix + vowel)
            }
            table.formUnion([prefix + "tu", prefix + "ya", prefix + "yu", prefix + "yo"])
        }
        return table
    }()

    private static let maxSyllableLength = syllables.map(\.count).max()!
}
