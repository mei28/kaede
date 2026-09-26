import Carbon

/// Kaede acts only while the Roman (英字) input source is selected.
enum InputSourceGuard {
    static let romanID = "com.apple.inputmethod.Kotoeri.RomajiTyping.Roman"

    /// Queried on every key rather than cached from change notifications, so it can never go stale.
    static func isRomanSelected() -> Bool {
        currentID() == romanID
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
