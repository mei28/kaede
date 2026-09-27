import Carbon
import Foundation

/// Tells whenever the selected input source changes, whoever changes it: Kaede itself, or the
/// user through Hammerspoon's cmd keys. Checking the source on each key misses left cmd followed
/// by right cmd, which ends on azooKey again but with Hammerspoon's own remapping.
@MainActor
final class InputSourceWatcher: NSObject {
    private let onChange: @MainActor () -> Void

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
        // Kaede never becomes the active app, and AppKit holds distributed notifications back
        // from inactive apps unless they ask to have them at once
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(changed),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func changed() {
        onChange()
    }
}
