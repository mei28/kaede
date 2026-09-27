import AppKit
import KaedeCore
import KaedeRemote

guard let resources = Bundle.main.resourceURL else {
    terminate("Kaede must run from its .app bundle (just run).")
}
Startup.verify()
let formKeys = FormSettings.load()
// Windows, menus and event monitors need the application object; NSApp stays nil until it is made
let application = NSApplication.shared

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

let keyHandler = FormKeyHandler(engine: SwitchEngine(rule: DictionaryRule(lexicon: lexicon)), jev: JevSwitchRequest(apiKey: jevKey))
keyHandler.start()

// Switching apps moves the caret out of the word.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { keyHandler.caretMoved() }
}
InputForm.installEditMenu()
let inputForm = InputForm(keys: formKeys, handler: keyHandler)
let formHotKey = HotKey(formKeys.open) { inputForm.toggle() }
let inputSourceWatcher = InputSourceWatcher { keyHandler.inputSourceChanged() }

log.notice("Kaede started.")
application.run()
