/// Moves the border between phrases of a clause, as Shift+arrows do in an input method.
public enum PhraseReadings {
    /// The readings with the phrase at `index` one character shorter (`delta` -1) or longer (+1),
    /// or nil when it cannot change: a phrase keeps at least one character, and the last one has
    /// nothing to take.
    ///
    /// A shorter phrase gives its last character to the next phrase, or to a new one after it; a
    /// longer one takes the next phrase's first character, and a next phrase left empty goes.
    public static func resized(_ readings: [String], at index: Int, by delta: Int) -> [String]? {
        precondition(delta == 1 || delta == -1, "a border moves one character at a time")
        var readings = readings
        let next = index + 1
        if delta < 0 {
            guard readings[index].count > 1 else { return nil }
            let character = readings[index].removeLast()
            if next < readings.count {
                readings[next].insert(character, at: readings[next].startIndex)
            } else {
                readings.append(String(character))
            }
        } else {
            guard next < readings.count else { return nil }
            readings[index].append(readings[next].removeFirst())
            if readings[next].isEmpty {
                readings.remove(at: next)
            }
        }
        return readings
    }
}
