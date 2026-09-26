/// A space-free stretch of a run, read in both layouts (one character per run element).
struct Token: Equatable {
    var qwerty: String
    var ebi: String
}

/// A run split at its spaces.
enum RunItem: Equatable {
    case token(Token)
    case separator(String)
}
