/// Decides whether a chunk reads as romaji from start to end.
public enum RomajiParser {
    public static func isRomaji(_ chunk: String) -> Bool {
        let characters = Array(chunk)
        // reachable[i]: the first i characters split into syllables with nothing left over
        var reachable = Array(repeating: false, count: characters.count + 1)
        reachable[0] = true
        for start in characters.indices where reachable[start] {
            for end in syllableEnds(in: characters, from: start) {
                reachable[end] = true
            }
        }
        return reachable[characters.count]
    }

    /// The positions where a syllable starting at `start` can end, shortest first.
    /// A sokuon (the first of a doubled consonant) counts as a syllable of its own.
    static func syllableEnds(in characters: [Character], from start: Int) -> [Int] {
        var ends: [Int] = []
        if isSokuon(characters, at: start) {
            ends.append(start + 1)
        }
        for length in 1...maxSyllableLength where start + length <= characters.count {
            if syllables.contains(String(characters[start..<start + length])) {
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
        // the chunk is readable, so it needs no lookahead here.
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
