import ApplicationServices
import Foundation

/// Checks what Kaede needs before installing the tap, and exits with status 1 when anything is missing.
enum Startup {
    static func verify(dictionaryDirectory: URL) {
        // The value of kAXTrustedCheckOptionPrompt, which Swift 6 rejects as shared mutable state.
        if !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
            terminate("Accessibility is not granted. Allow Kaede in System Settings > Privacy & Security > Accessibility, then start it again.")
        }
        if !CGPreflightListenEventAccess() {
            CGRequestListenEventAccess()
            terminate("Input Monitoring is not granted. Allow Kaede in System Settings > Privacy & Security > Input Monitoring, then start it again.")
        }
        if !InputSourceGuard.isRomanEnabled() {
            terminate("The input source \(InputSourceGuard.romanID) is not enabled.")
        }
        if !FileManager.default.fileExists(atPath: dictionaryDirectory.path(percentEncoded: false)) {
            terminate("The conversion dictionary is missing at \(dictionaryDirectory.path(percentEncoded: false)). Build the app with `just bundle`.")
        }
    }
}
