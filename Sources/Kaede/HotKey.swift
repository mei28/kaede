import Carbon
import KaedeCore

/// A system-wide hot key. Unlike the event tap, it works while secure input is on and does not
/// depend on the order of the taps (Hammerspoon's reload puts its taps first).
@MainActor
final class HotKey {
    private let action: @MainActor () -> Void
    private var reference: EventHotKeyRef?

    /// Stops Kaede when the key cannot be registered, as when another app holds it.
    init(_ combo: KeyCombo, action: @escaping @MainActor () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(), nil
        )
        guard handlerStatus == noErr else {
            terminate("Could not listen for the form key \(combo) (status \(handlerStatus)).")
        }
        // "KAED", as in the marker on Kaede's own events
        let id = EventHotKeyID(signature: OSType(0x4B41_4544), id: 1)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode), Self.carbonModifiers(of: combo.modifiers), id,
            GetApplicationEventTarget(), 0, &reference
        )
        guard status == noErr else {
            terminate("Could not register the form key \(combo) (status \(status)); another app may use it. Change it with `just form-key open`.")
        }
    }

    fileprivate func fire() {
        action()
    }

    private static func carbonModifiers(of modifiers: KeyCombo.Modifiers) -> UInt32 {
        var carbon = 0
        if modifiers.contains(.command) { carbon |= cmdKey }
        if modifiers.contains(.control) { carbon |= controlKey }
        if modifiers.contains(.option) { carbon |= optionKey }
        if modifiers.contains(.shift) { carbon |= shiftKey }
        return UInt32(carbon)
    }
}

/// Carbon calls the handlers of the application target on the main thread.
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    nonisolated(unsafe) let userData = userData
    MainActor.assumeIsolated {
        Unmanaged<HotKey>.fromOpaque(userData!).takeUnretainedValue().fire()
    }
    return noErr
}
