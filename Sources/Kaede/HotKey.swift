import Carbon
import KaedeCore

/// A system-wide hot key: it opens the form from any app, even while secure input is on, and
/// needs no permission.
@MainActor
final class HotKey {
    enum Failure: Error {
        /// Another app holds the key, or macOS refuses it.
        case notRegistered(KeyCombo, OSStatus)
    }

    private let action: @MainActor () -> Void
    private var reference: EventHotKeyRef?
    private(set) var combo: KeyCombo

    /// Stops Kaede when the key cannot be registered, as when another app holds it.
    init(_ combo: KeyCombo, action: @escaping @MainActor () -> Void) {
        self.action = action
        self.combo = combo
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(), hotKeyHandler, 1, &pressed,
            Unmanaged.passUnretained(self).toOpaque(), nil
        )
        guard handlerStatus == noErr else {
            terminate("Could not listen for the form key \(combo) (status \(handlerStatus)).")
        }
        do {
            try register(combo)
        } catch {
            terminate("Could not register the form key \(combo) (\(error)); another app may use it. Change it with `just form-key open`.")
        }
    }

    /// Moves the hot key to another combo; when that fails, the old combo stays.
    func change(to newCombo: KeyCombo) throws {
        suspend()
        do {
            try register(newCombo)
            combo = newCombo
        } catch {
            try register(combo)
            throw error
        }
    }

    /// Lets the combo through to Kaede's windows, as while the settings record a key.
    func suspend() {
        if let reference {
            UnregisterEventHotKey(reference)
            self.reference = nil
        }
    }

    func resume() throws {
        guard reference == nil else { return }
        try register(combo)
    }

    private func register(_ combo: KeyCombo) throws {
        // "KAED", as in the marker on Kaede's own events
        let id = EventHotKeyID(signature: OSType(0x4B41_4544), id: 1)
        let status = RegisterEventHotKey(
            UInt32(combo.keyCode), Self.carbonModifiers(of: combo.modifiers), id,
            GetApplicationEventTarget(), 0, &reference
        )
        guard status == noErr else {
            throw Failure.notRegistered(combo, status)
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
