import AppKit
import KaedeCore
import KaedeRemote

guard let resources = Bundle.main.resourceURL else {
    terminate("Kaede must run from its .app bundle (just run).")
}
Startup.verify()

// The dictionary rule only feeds the log, next to Jev's answers
let lexicon: EnglishLexicon
do {
    let bundledLists = ["en10k.txt", "extra-words.txt"].map { resources.appending(path: $0).path(percentEncoded: false) }
    lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledLists)
} catch {
    terminate("Could not read the English word lists: \(error)")
}

// Without Jev, Kaede has nothing to decide with
let jevKey: String
do {
    guard let key = try Keychain.apiKey(named: "jev") else {
        terminate("No Jev API key is stored. Store it with `just set-key jev`, then start Kaede again.")
    }
    jevKey = key
} catch {
    terminate("Could not read the Jev API key: \(error)")
}

let tap = EventTap(engine: SwitchEngine(rule: DictionaryRule(lexicon: lexicon)), jev: JevSwitchRequest(apiKey: jevKey))
tap.start()

// Switching apps moves the caret out of the word.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { tap.caretMoved() }
}
let inputSourceWatcher = InputSourceWatcher { tap.inputSourceChanged() }

log.notice("Kaede started.")
NSApplication.shared.run()
