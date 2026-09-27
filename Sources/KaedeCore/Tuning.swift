/// The numbers that decide when Kaede switches, kept in one place. They are jev-auto-ime's
/// defaults; change them here after watching how switching goes wrong.
public enum Tuning {
    /// Words shorter than this are neither asked about nor switched.
    public static let minimumStrokes = 3
    /// No answer below this confidence counts toward a switch.
    public static let confidenceFloor = 0.35
    /// The confidence an answer needs to switch after a pause, and to oppose another answer.
    public static let confidence = 0.55
    /// An answer this confident, with nothing opposing it, switches at once.
    public static let immediateConfidence = 0.90
    /// Answers in a row that switch when they agree; also how far back an answer can oppose.
    public static let streakLength = 3
    /// How long the hands rest on the latest answer before it switches.
    public static let pause: Duration = .milliseconds(350)
    /// The same, when an opposing answer came just before.
    public static let opposedPause: Duration = .milliseconds(700)
}
