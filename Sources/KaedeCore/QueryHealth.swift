/// Whether Jev's questions are failing, so that the user hears one beep when failures start
/// rather than one per key. Failed questions are not retried: the next key asks again.
public struct QueryHealth: Sendable {
    private var failing = false

    public init() {}

    /// Records a failure; true when it is the first since a success (or since the start).
    public mutating func failed() -> Bool {
        defer { failing = true }
        return !failing
    }

    public mutating func succeeded() {
        failing = false
    }
}
