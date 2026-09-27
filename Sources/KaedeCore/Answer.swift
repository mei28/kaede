/// What the word being typed is: English as it shows on screen, or Japanese romaji typed with
/// QWERTY or Ebi fingering. `keep` leaves the decision to later keys. The raw values are the
/// options Jev chooses from.
public enum Answer: String, CaseIterable, Sendable {
    case english
    case japaneseQwerty = "japanese_qwerty"
    case japaneseEbi = "japanese_ebi"
    case keep
}
