import AppKit
import KaedeConverter
import KaedeCore
import KaedeRemote

guard let resources = Bundle.main.resourceURL else {
    terminate("Kaede must run from its .app bundle (just run).")
}
let dictionaryDirectory = resources.appending(path: "Dictionary", directoryHint: .isDirectory)
Startup.verify(dictionaryDirectory: dictionaryDirectory)

let lexicon: EnglishLexicon
// The top-10k list and the user's words: only these respace English typed without spaces
let commonWords: EnglishLexicon
do {
    let bundledLists = ["en10k.txt", "extra-words.txt"].map { resources.appending(path: $0).path(percentEncoded: false) }
    lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledLists)
    commonWords = try EnglishLexicon(contentsOfFiles: bundledLists)
} catch {
    terminate("Could not read the English word lists: \(error)")
}

// Jev settles ambiguous words when its key is stored; without it the rules do
let jev: JevLanguageRequest?
do {
    jev = try Keychain.apiKey(named: "jev").map(JevLanguageRequest.init(apiKey:))
} catch {
    terminate("Could not read the Jev API key: \(error)")
}
log.notice("Jev is \(jev == nil ? "off (no key stored)" : "on", privacy: .public).")

let tap = EventTap(
    planner: EnterPlanner(lexicon: lexicon, commonWords: commonWords),
    converter: AzooKeyConverter(
        dictionaryDirectory: dictionaryDirectory,
        memoryDirectory: FileManager.default.temporaryDirectory
    ),
    jev: jev
)
tap.start()

// Switching apps moves the caret out of the run.
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
) { _ in
    MainActor.assumeIsolated { tap.discardRun() }
}

log.notice("Kaede started.")
NSApplication.shared.run()
