import AppKit
import KaedeCore

/// Types the input form's text into the app it came from, as key events: the clipboard stays
/// untouched.
@MainActor
struct TextInserter {
    enum Failure: Error {
        /// The app the text goes to did not get the keys back.
        case focusNotBack
        /// Held modifiers would join the typed keys (Shift would select, cmd would run shortcuts).
        case modifiersHeld
        case secureInput
        /// azooKey would read the typed text as its own input.
        case romanNotSelected
    }

    private let poster = EventPoster()

    /// The pause between pieces, so the app keeps up with the typed text.
    private static let pieceGap: Duration = .milliseconds(5)

    /// Selects the Roman source if azooKey was selected by hand in the form, then types the pieces.
    func type(_ pieces: [TypingPiece], into pid: pid_t) async throws {
        guard await Self.waitUntil(.milliseconds(500), { Self.focusedApplication() == pid }) else {
            throw Failure.focusNotBack
        }
        guard await Self.waitUntil(.seconds(1), { CGEventSource.flagsState(.combinedSessionState).isDisjoint(with: Self.modifierFlags) }) else {
            throw Failure.modifiersHeld
        }
        guard !SecureInput.isEnabled else {
            throw Failure.secureInput
        }
        if InputSourceGuard.current() != .roman {
            guard await InputSourceSwitcher.select(InputSourceGuard.romanID) else {
                throw Failure.romanNotSelected
            }
            await InputSourceSwitcher.pause(InputSourceSwitcher.settleDelay)
        }
        for piece in pieces {
            switch piece {
            case let .text(text):
                poster.typePiece(text)
            case .newline:
                poster.newline()
            }
            await InputSourceSwitcher.pause(Self.pieceGap)
        }
        let newlines = pieces.count { $0 == .newline }
        log.info("Put the form's text into the app: \(pieces.count - newlines, privacy: .public) pieces, \(newlines, privacy: .public) newlines.")
    }

    private static let modifierFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]

    /// The process of the app that has the keyboard focus, from the accessibility API: the form
    /// hands the activation back, and the keys must wait until that app has it.
    private static func focusedApplication() -> pid_t? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(focused as! AXUIElement, &pid) == .success else { return nil }
        return pid
    }

    /// Checks `condition` every 10 ms until it holds or `timeout` passes.
    private static func waitUntil(_ timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let started = clock.now
        while clock.now - started < timeout {
            if condition() {
                return true
            }
            await InputSourceSwitcher.pause(.milliseconds(10))
        }
        return condition()
    }
}
