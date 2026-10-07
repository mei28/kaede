import AppKit

/// Looks at the keys typed into the input form before the text view and the input method do,
/// so the form's insert key works even while an input method composes.
///
/// Kaede sees only its own keys: other apps' keys never reach it, so it needs no input
/// monitoring. The form is the active app's key window while it is open.
@MainActor
final class FormKeyHandler {
    private var monitor: Any?
    /// The form's window: only its keys are looked at (not those of the settings, say).
    weak var formWindow: NSWindow?
    /// Looks at a key of the form; returns whether it took the key (the form's insert key).
    var interceptor: ((NSEvent) -> Bool)?

    /// Watches the key events Kaede receives, before its windows and the input method see them.
    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Local monitors run on the main thread
            nonisolated(unsafe) let event = event
            return MainActor.assumeIsolated {
                EventBox(event: self?.takes(event) == true ? nil : event)
            }.event
        }
    }

    private func takes(_ event: NSEvent) -> Bool {
        guard let formWindow, event.window === formWindow else {
            return false
        }
        return interceptor?(event) == true
    }
}

/// Carries an event out of `MainActor.assumeIsolated`, which wants a Sendable result; the event
/// never leaves the main thread.
private struct EventBox: @unchecked Sendable {
    let event: NSEvent?
}
