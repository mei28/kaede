import AppKit
import KaedeCore

/// The session event tap: feeds key and mouse events to the engine and carries out its decisions.
@MainActor
final class EventTap {
    private let engine: KeyEngine
    /// The engine's planner, reused to find other splits when building candidates.
    private let planner: EnterPlanner
    private let converter: any KanaKanjiConverting
    private let poster = EventPoster()
    private var machPort: CFMachPort?

    /// Candidates offered after a conversion.
    private static let candidateLimit = 8
    /// Splits tried per token for the candidates' other splits.
    private static let splitsPerToken = 3

    init(planner: EnterPlanner, converter: any KanaKanjiConverting) {
        self.engine = KeyEngine(planner: planner)
        self.planner = planner
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
        log.debug("keyDown received (Kaede's own: \(key.isKaedeEvent, privacy: .public))")
        if !key.isKaedeEvent, SecureInput.isEnabled {
            log.info("Skipped: secure input is on.")
            engine.discardRun()
            return true
        }
        if !key.isKaedeEvent, !InputSourceGuard.isRomanSelected() {
            log.info("Skipped: input source is \(InputSourceGuard.currentID() ?? "unknown", privacy: .public).")
            engine.discardRun()
            return true
        }
        // Enter and Space end the run and are planned inside this callback, so time them
        let endsRun = [36, 76, 49].contains(key.keyCode)
        let clock = ContinuousClock()
        let started = clock.now
        let response = engine.handle(key)
        if endsRun {
            let (seconds, attoseconds) = (clock.now - started).components
            let microseconds = seconds * 1_000_000 + attoseconds / 1_000_000_000_000
            log.info("Planned in \(microseconds, privacy: .public) µs.")
        }
        switch response {
        case .pass:
            if endsRun { log.info("Run passed through.") }
            return true
        case .suppress:
            return false
        case let .replace(replacement):
            log.info("Run converts: deleting \(replacement.deleteCount, privacy: .public) characters.")
            // Replace after the callback returns, so the tap is not held up by the conversion.
            DispatchQueue.main.async { self.replace(replacement) }
            return false
        case let .rewrite(deleteCount, text):
            log.info("Rewrites \(deleteCount, privacy: .public) characters with a candidate or the typed text.")
            DispatchQueue.main.async { self.rewrite(deleteCount: deleteCount, text: text) }
            return false
        }
    }

    private func replace(_ replacement: Replacement) {
        do {
            let text = try replacement.text(using: converter)
            poster.deleteBackward(replacement.deleteCount)
            poster.type(text + replacement.suffix)
            log.info("Replaced with \(text.count, privacy: .public) characters.")
        } catch {
            // The run stays on screen as typed. The space that triggered the conversion is still
            // typed; a swallowed Enter is not sent.
            log.error("Conversion failed: \(error)")
            NSSound.beep()
            poster.type(replacement.suffix)
            finishReplacement(candidates: [])
            return
        }
        // Built after the conversion is on screen, so it does not delay it
        do {
            finishReplacement(candidates: try timedCandidates(for: replacement))
        } catch {
            log.error("Building candidates failed, so this conversion cannot be stepped through: \(error)")
            finishReplacement(candidates: [])
        }
    }

    private func finishReplacement(candidates: [String]) {
        for key in engine.finishReplacement(candidates: candidates) {
            poster.replay(key)
        }
    }

    private func timedCandidates(for replacement: Replacement) throws -> [String] {
        let clock = ContinuousClock()
        let started = clock.now
        let alternatives = planner.alternatives(for: Run(typing: replacement.typed), perToken: Self.splitsPerToken)
        let candidates = try replacement.candidates(using: converter, alternatives: alternatives, limit: Self.candidateLimit)
        log.info("Built \(candidates.count, privacy: .public) candidates in \(clock.now - started, privacy: .public).")
        return candidates
    }

    private func rewrite(deleteCount: Int, text: String) {
        poster.deleteBackward(deleteCount)
        poster.type(text)
        for key in engine.finishRewrite() {
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
