import AppKit
import KaedeCore
import KaedeRemote

/// Feeds the keys typed into the input form to the engine, asks Jev what it asks for, and
/// carries out the switches it decides.
///
/// Kaede sees only its own keys: other apps' keys never reach it, so it needs no input
/// monitoring. The form is the active app's key window while it is open.
@MainActor
final class FormKeyHandler {
    private let engine: SwitchEngine
    private var jev: JevSwitchRequest
    private let transport = URLSessionTransport()
    private let poster = EventPoster()
    private var monitor: Any?
    private var health = QueryHealth()
    /// Wakes the engine when a pause would settle the latest answer.
    private var pauseTimer: Task<Void, Never>?
    private var timerDeadline: ContinuousClock.Instant?
    /// The app the input form writes for, while it is open: Jev hears about that app, not Kaede.
    var formTarget: String?
    /// The form's window: only its keys go to the engine (not those of the settings, say).
    weak var formWindow: NSWindow?
    /// Looks at a key of the form before the engine and the input method; returns whether it
    /// took the key (the form's insert key).
    var interceptor: ((NSEvent) -> Bool)?
    /// Called when the input source or Kaede's switching changes, for the form's mode display.
    var onStateChange: (() -> Void)?
    /// Totals for the log.
    private var questionsAnswered = 0
    private var inputTokens = 0

    init(engine: SwitchEngine, jev: JevSwitchRequest) {
        self.engine = engine
        self.jev = jev
    }

    /// Watches the events Kaede receives, before its windows and the input method see them.
    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            // Local monitors run on the main thread
            nonisolated(unsafe) let event = event
            return MainActor.assumeIsolated {
                EventBox(event: self.map { $0.handle(event) } ?? event)
            }.event
        }
    }

    /// A new API key from the settings, used from the next question.
    func useJevKey(_ apiKey: String) {
        jev = JevSwitchRequest(apiKey: apiKey)
    }

    /// Kaede is typing into the app to move a word to azooKey or English back.
    var isSwitching: Bool {
        engine.isSwitching
    }

    /// Kaede reads keys through a layout in the azooKey it switched to.
    var isRemapping: Bool {
        engine.isRemapping
    }

    /// The Japanese answer whose layout Kaede reads keys through, if it does.
    var remappingAnswer: Answer? {
        engine.remappingAnswer
    }

    /// A click or another app: the caret may be anywhere now.
    func caretMoved() {
        apply(engine.caretMoved())
    }

    func inputSourceChanged() {
        engine.inputSourceChanged(to: InputSourceGuard.current())
        rescheduleTimer()
        onStateChange?()
    }

    /// The event to go on with: the event itself, another key in its place, or nil to drop it.
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard let formWindow, event.window === formWindow else {
            return event
        }
        guard event.type == .keyDown else {
            caretMoved()
            return event
        }
        if interceptor?(event) == true {
            return nil
        }
        let key = KeyEventBridge.rawKey(from: event)
        let (action, reaction) = engine.handle(key, source: InputSourceGuard.current(), at: .now)
        apply(reaction)
        switch action {
        case .pass:
            return event
        case .suppress:
            return nil
        case let .remap(keyCode):
            // In place of the event, so the key keeps its turn
            return KeyEventBridge.event(from: event, keyCode: keyCode)
        }
    }

    private func apply(_ reaction: Reaction) {
        if let word = reaction.finishedWord {
            log.info("Word finished: rule \(word.rule.rawValue, privacy: .public), Jev \(word.jev.rawValue, privacy: .public), \(word.agrees ? "agree" : "disagree", privacy: .public).")
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
        onStateChange?()
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

    /// Posts held keys again, unmarked, so they come back through the key handler in their order.
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

/// Carries an event out of `MainActor.assumeIsolated`, which wants a Sendable result; the event
/// never leaves the main thread.
private struct EventBox: @unchecked Sendable {
    let event: NSEvent?
}
