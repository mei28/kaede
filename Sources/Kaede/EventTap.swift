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

    /// A click or an app switch. When azooKey holds a handed-off word, it commits the word as
    /// focus moves, and Kaede switches back to English.
    func discardRun() {
        if engine.isWithAzooKey {
            Task { _ = await InputSourceSwitcher.select(InputSourceGuard.romanID) }
        }
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
            discardRun()
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
        if engine.isWithAzooKey, InputSourceGuard.currentID() != InputSourceSwitcher.azooKeyID {
            // The user or Hammerspoon (on Escape) left azooKey, which committed its word
            log.info("azooKey was left by other means.")
            engine.azooKeyWasLeft()
        }
        // While azooKey holds a handed-off word, Kaede still watches keys to settle it
        if !key.isKaedeEvent, !engine.isWithAzooKey, !InputSourceGuard.isRomanSelected() {
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
        case let .handOff(handOff):
            log.info("Hands \(handOff.romaji.count, privacy: .public) romaji characters to azooKey.")
            Task { await self.handOff(handOff) }
            return false
        case let .settle(replay):
            log.info("Settles the word in azooKey\(replay == nil ? "" : " and types the next key in English", privacy: .public).")
            Task { await self.settle(replaying: replay) }
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

    /// Settles the parts before the last Japanese part, switches to azooKey and types that part
    /// into it with the Space that converts it. When switching fails, the part stays as typed.
    private func handOff(_ handOff: HandOff) async {
        if !handOff.settled.isEmpty {
            let settled: String
            do {
                settled = try Replacement(typed: handOff.typed, pieces: handOff.settled).text(using: converter)
            } catch {
                log.error("Conversion before the hand-off failed: \(error)")
                failHandOff()
                return
            }
            poster.deleteBackward(handOff.typed.count)
            poster.type(settled + handOff.typedTail)
            await InputSourceSwitcher.pause(InputSourceSwitcher.settleDelay)
        }
        guard await InputSourceSwitcher.select(InputSourceSwitcher.azooKeyID) else {
            failHandOff()
            return
        }
        poster.deleteBackward(handOff.typedTail.count)
        poster.typeKeys(handOff.romaji)
        poster.press(49)  // Space: azooKey converts and shows its candidates
        for key in engine.finishHandOff(succeeded: true) {
            poster.replay(key)
        }
    }

    /// The keys stay as typed; the Space that triggered the hand-off is still typed.
    private func failHandOff() {
        NSSound.beep()
        poster.type(" ")
        for key in engine.finishHandOff(succeeded: false) {
            poster.replay(key)
        }
    }

    /// Commits the word azooKey holds, switches back to English, and types `replay` there.
    private func settle(replaying replay: RawKey?) async {
        poster.press(36)  // Return: azooKey commits its word
        await InputSourceSwitcher.pause(InputSourceSwitcher.settleDelay)
        if !(await InputSourceSwitcher.select(InputSourceGuard.romanID)) {
            // azooKey stays selected, so the key lands in azooKey; typing it still beats losing it.
            // Kaede skips keys until the user switches back.
            NSSound.beep()
        }
        if let replay {
            poster.replay(replay)
        }
        for key in engine.finishSettle() {
            poster.replay(key)
        }
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
