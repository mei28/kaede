/// A stretch of layout keys in a run, read in both layouts (one character per run element).
struct Token: Equatable {
    var qwerty: String
    var ebi: String
}

/// A run split into tokens and the literals between them.
enum RunItem: Equatable {
    case token(Token)
    case separator(String)
}
