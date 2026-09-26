import AppKit
import KaedeCore

/// The session event tap: feeds key and mouse events to the engine and carries out its decisions.
@MainActor
final class EventTap {
    private let engine: KeyEngine
    private let converter: any KanaKanjiConverting
    private let poster = EventPoster()
    private var machPort: CFMachPort?

    init(engine: KeyEngine, converter: any KanaKanjiConverting) {
        self.engine = engine
        self.converter = converter
    }

    func start() {
        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            terminate("Could not create the event tap.")
        }
        machPort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func discardRun() {
        engine.discardRun()
    }

    /// Returns whether the event goes on to the apps.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system turns off a tap that answers too slowly; turn it straight back on.
            log.notice("Event tap was disabled; enabling it again.")
            if let machPort { CGEvent.tapEnable(tap: machPort, enable: true) }
            return true
        case .keyDown:
            return handleKeyDown(event)
        default:
            engine.discardRun()
            return true
        }
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        let key = CGEventBridge.rawKey(from: event)
        if !key.isKaedeEvent, SecureInput.isEnabled || !InputSourceGuard.isRomanSelected() {
            engine.discardRun()
            return true
        }
        switch engine.handle(key) {
        case .pass:
            return true
        case .suppress:
            return false
        case let .replace(replacement):
            // Replace after the callback returns, so the tap is not held up by the conversion.
            DispatchQueue.main.async { self.replace(replacement) }
            return false
        }
    }

    private func replace(_ replacement: Replacement) {
        do {
            let text = try replacement.text(using: converter)
            poster.deleteBackward(replacement.deleteCount)
            poster.type(text)
        } catch {
            // The swallowed Enter is not sent: the run stays on screen as typed.
            log.error("Conversion failed: \(error)")
            NSSound.beep()
        }
        for key in engine.finishReplacement() {
            poster.replay(key)
        }
    }
}

private func tapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // The run loop source is on the main run loop, so the callback already runs on the main
    // thread and nothing is actually sent across threads.
    nonisolated(unsafe) let event = event
    nonisolated(unsafe) let userInfo = userInfo
    let passes = MainActor.assumeIsolated {
        Unmanaged<EventTap>.fromOpaque(userInfo!).takeUnretainedValue().handle(type, event)
    }
    return passes ? Unmanaged.passUnretained(event) : nil
}
