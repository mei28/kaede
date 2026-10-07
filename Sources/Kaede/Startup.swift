import ApplicationServices

/// Checks what Kaede needs before it starts, and exits with status 1 when anything is missing.
/// Posting keys needs Accessibility; Kaede reads only its own keys, so it needs no Input Monitoring.
enum Startup {
    static func verify() {
        // The value of kAXTrustedCheckOptionPrompt, which Swift 6 rejects as shared mutable state.
        if !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
            terminate("Accessibility is not granted. Allow Kaede in System Settings > Privacy & Security > Accessibility, then start it again.")
        }
        if !InputSourceGuard.isRomanEnabled() {
            terminate("The input source \(InputSourceGuard.romanID) is not enabled.")
        }
    }
}
