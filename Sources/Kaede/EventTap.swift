import AppKit
import KaedeCore
import KaedeRemote

/// The session event tap: feeds keys and clicks to the engine, asks Jev what it asks for, and
/// carries out the switches it decides.
@MainActor
final class EventTap {
    private let engine: SwitchEngine
    private let jev: JevSwitchRequest
    private let transport = URLSessionTransport()
    private let poster = EventPoster()
    private let pauseSound: NSSound
    private var machPort: CFMachPort?
    private var health = QueryHealth()
    /// Wakes the engine when a pause would settle the latest answer.
    private var pauseTimer: Task<Void, Never>?
    private var timerDeadline: ContinuousClock.Instant?
    /// The app the input form writes for, while it is open: Jev hears about that app, not Kaede.
    var formTarget: String?
    /// Totals for the log.
    private var questionsAnswered = 0
    private var inputTokens = 0

    init(engine: SwitchEngine, jev: JevSwitchRequest) {
        self.engine = engine
        self.jev = jev
        // A system sound unlike the failure beep
        guard let sound = NSSound(named: "Tink") else {
            terminate("The system sound Tink is missing.")
        }
        pauseSound = sound
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

    /// Kaede is typing into the app to move a word to azooKey or English back.
    var isSwitching: Bool {
        engine.isSwitching
    }

    /// Kaede reads keys through a layout in the azooKey it switched to.
    var isRemapping: Bool {
        engine.isRemapping
    }

    /// A click or another app: the caret may be anywhere now.
    func caretMoved() {
        apply(engine.caretMoved())
    }

    func inputSourceChanged() {
        engine.inputSourceChanged(to: InputSourceGuard.current())
        rescheduleTimer()
    }

    /// Returns whether the event goes on to the apps.
    fileprivate func handle(_ type: CGEventType, _ event: CGEvent, proxy: CGEventTapProxy) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system turns off a tap that answers too slowly; turn it straight back on.
            log.notice("Event tap was disabled; enabling it again.")
            if let machPort { CGEvent.tapEnable(tap: machPort, enable: true) }
            return true
        case .keyDown:
            return handleKeyDown(event, proxy: proxy)
        default:
            caretMoved()
            return true
        }
    }

    private func handleKeyDown(_ event: CGEvent, proxy: CGEventTapProxy) -> Bool {
        let key = CGEventBridge.rawKey(from: event)
        if !key.isKaedeEvent, SecureInput.isEnabled {
            log.info("Skipped: secure input is on.")
            caretMoved()
            return true
        }
        let (action, reaction) = engine.handle(key, source: InputSourceGuard.current(), at: .now)
        apply(reaction)
        switch action {
        case .pass:
            return true
        case .suppress:
            return false
        case let .remap(keyCode):
            poster.remap(keyCode: keyCode, flags: CGEventBridge.flags(of: key), proxy: proxy)
            return false
        }
    }

    private func apply(_ reaction: Reaction) {
        if let word = reaction.finishedWord {
            log.info("Word finished: rule \(word.rule.rawValue, privacy: .public), Jev \(word.jev.rawValue, privacy: .public), \(word.agrees ? "agree" : "disagree", privacy: .public).")
        }
        if reaction.paused {
            pauseSound.play()
            log.notice("Paused until Enter.")
        }
        if let question = reaction.question {
            Task { await ask(question) }
        }
        if let order = reaction.switchOrder {
            Task { await perform(order) }
        }
        if reaction.switchBack {
            Task { await switchBack() }
        }
        rescheduleTimer()
    }

    private func ask(_ question: Question) async {
        // Kaede asks only while the Roman source is selected
        let request = jev.urlRequest(
            question: question,
            application: formTarget ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            inputSource: InputSourceGuard.romanID
        )
        do {
            let (data, status) = try await transport.send(request)
            let (judgment, tokens) = try JevSwitchResponse.read(data, status: status, offered: question.options)
            questionsAnswered += 1
            inputTokens += tokens
            log.info("Jev answered \(judgment.answer.rawValue, privacy: .public) (\(judgment.confidence, privacy: .public)) about \(question.keys.count, privacy: .public) keys; \(self.questionsAnswered, privacy: .public) answers, \(self.inputTokens, privacy: .public) input tokens so far.")
            health.succeeded()
            apply(engine.receive(judgment, to: question.id, at: .now))
        } catch JevError.unauthorized {
            terminate("Jev rejected the API key (401). Store a valid one with `just set-key jev`, then start Kaede again.")
        } catch {
            log.error("Asking Jev failed: \(error)")
            if health.failed() {
                NSSound.beep()
            }
            engine.questionFailed(question.id)
        }
    }

    /// Selects azooKey, then replaces the word's keys on screen with its romaji typed into azooKey.
    /// Switching first means a failed switch leaves the word as typed.
    private func perform(_ order: SwitchOrder) async {
        guard await InputSourceSwitcher.select(InputSourceSwitcher.azooKeyID) else {
            log.error("Switching to azooKey failed; the word stays as typed.")
            NSSound.beep()
            replay(engine.switchFailed())
            return
        }
        poster.deleteBackward(order.deleteCount)
        poster.typeKeys(order.romaji)
        log.info("Switched a word of \(order.deleteCount, privacy: .public) keys to azooKey as \(order.answer.rawValue, privacy: .public).")
        replay(engine.switchSucceeded())
    }

    /// Selects the Roman source again once azooKey has committed with the Enter that just passed.
    private func switchBack() async {
        await InputSourceSwitcher.pause(InputSourceSwitcher.commitDelay)
        guard await InputSourceSwitcher.select(InputSourceGuard.romanID) else {
            log.error("Switching back to the Roman source failed; azooKey keeps the keys.")
            NSSound.beep()
            replay(engine.switchBackFailed())
            return
        }
        log.info("Switched back to the Roman source after Enter.")
        replay(engine.switchedBack())
    }

    /// Posts held keys again, unmarked, so they come back through the tap in their order.
    private func replay(_ keys: [RawKey]) {
        for key in keys {
            poster.replay(key)
        }
    }

    /// Keeps one timer, set for the engine's deadline.
    private func rescheduleTimer() {
        let deadline = engine.deadline
        guard deadline != timerDeadline else { return }
        pauseTimer?.cancel()
        timerDeadline = deadline
        guard let deadline else {
            pauseTimer = nil
            return
        }
        pauseTimer = Task {
            do {
                try await Task.sleep(until: deadline, clock: .continuous)
            } catch {
                // Cancelled: a later deadline took this one's place
                return
            }
            timerDeadline = nil
            apply(engine.tick(at: .now))
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
    nonisolated(unsafe) let proxy = proxy
    let passes = MainActor.assumeIsolated {
        Unmanaged<EventTap>.fromOpaque(userInfo!).takeUnretainedValue().handle(type, event, proxy: proxy)
    }
    return passes ? Unmanaged.passUnretained(event) : nil
}
