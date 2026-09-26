import AppKit
import KaedeConverter
import KaedeCore

guard let resources = Bundle.main.resourceURL else {
    terminate("Kaede must run from its .app bundle (just run).")
}
let dictionaryDirectory = resources.appending(path: "Dictionary", directoryHint: .isDirectory)
Startup.verify(dictionaryDirectory: dictionaryDirectory)

let lexicon: EnglishLexicon
do {
    lexicon = try EnglishLexicon(contentsOfFile: "/usr/share/dict/words")
} catch {
    terminate("Could not read /usr/share/dict/words: \(error)")
}

let tap = EventTap(
    engine: KeyEngine(planner: EnterPlanner(lexicon: lexicon)),
    converter: AzooKeyConverter(
        dictionaryDirectory: dictionaryDirectory,
        memoryDirectory: FileManager.default.temporaryDirectory
    )
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
