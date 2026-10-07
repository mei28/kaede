import Carbon

/// Selects an input source and waits until it is the current one.
///
/// TISSelectInputSource can return before the switch takes effect, so the result is checked
/// against the current source until `timeout`.
@MainActor
enum InputSourceSwitcher {
    /// Long enough for a normal switch; a longer wait would stall typing.
    static let timeout: Duration = .milliseconds(300)
    /// Lets keys posted before a switch reach the app under the source they were meant for.
    static let settleDelay: Duration = .milliseconds(50)

    /// Whether the source became current within `timeout`.
    static func select(_ id: String) async -> Bool {
        guard let source = inputSource(id) else {
            log.error("Input source \(id, privacy: .public) is not enabled.")
            return false
        }
        guard TISSelectInputSource(source) == noErr else {
            log.error("Selecting \(id, privacy: .public) failed.")
            return false
        }
        let clock = ContinuousClock()
        let started = clock.now
        while clock.now - started < timeout {
            if InputSourceGuard.currentID() == id {
                log.info("Switched to \(id, privacy: .public) in \(clock.now - started, privacy: .public).")
                return true
            }
            await pause(.milliseconds(10))
        }
        log.error("Switching to \(id, privacy: .public) did not take effect within \(timeout, privacy: .public).")
        return false
    }

    /// Waits without blocking the main run loop, so Kaede keeps receiving keys.
    static func pause(_ duration: Duration) async {
        do {
            try await Task.sleep(for: duration)
        } catch {
            // Only cancellation throws, and nothing cancels these tasks
            preconditionFailure("input source wait was cancelled")
        }
    }

    nonisolated private static func inputSource(_ id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        // Bridging to a Swift array retains the element, which outlives the CFArray
        let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        return sources?.first
    }
}
