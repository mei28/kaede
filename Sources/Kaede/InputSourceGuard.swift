import Carbon
import KaedeCore

/// Which input source is selected: the form is written in the Roman (英字) source, and the text
/// goes into the app in it.
enum InputSourceGuard {
    static let romanID = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"
    static let azooKeyID = "dev.ensan.inputmethod.azooKeyMac.Japanese"

    /// Queried each time rather than cached from change notifications, so it can never go stale.
    static func current() -> InputSource {
        switch currentID() {
        case romanID: .roman
        case azooKeyID: .azooKey
        default: .other
        }
    }

    static func currentID() -> String? {
        inputSourceID(of: TISCopyCurrentKeyboardInputSource().takeRetainedValue())
    }

    static func isRomanEnabled() -> Bool {
        let filter = [kTISPropertyInputSourceID as String: romanID] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() else {
            return false
        }
        return CFArrayGetCount(sources) > 0
    }

    private static func inputSourceID(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
