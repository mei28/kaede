import AppKit
import KaedeConverter
import KaedeCore

guard let resources = Bundle.main.resourceURL else {
    terminate("Kaede must run from its .app bundle (just run).")
}
let dictionary = resources.appending(path: "Dictionary")
Startup.verify(dictionaryDirectory: dictionary)
FormSettings.registerDefaults()
let formKeys = FormSettings.load()
let fontSize = FormSettings.loadFontSize()
let punctuation = FormSettings.loadPunctuation()
// Windows, menus and event monitors need the application object; NSApp stays nil until it is made
let application = NSApplication.shared

let lexicon: EnglishLexicon
do {
    lexicon = try EnglishLexicon(contentsOfFiles: ["en10k.txt", "extra-words.txt"].map { resources.appending(path: $0).path(percentEncoded: false) })
} catch {
    terminate("Could not read the English word lists: \(error)")
}
let worker = ConversionWorker(dictionaryDirectory: dictionary, memoryDirectory: FileManager.default.temporaryDirectory, lexicon: lexicon)
Task {
    do {
        try await worker.warmUp()
    } catch {
        terminate("azooKey could not convert: \(error)")
    }
}

let keyHandler = FormKeyHandler()
keyHandler.start()

InputForm.installEditMenu()
let inputForm = InputForm(keys: formKeys, fontSize: fontSize, style: punctuation, handler: keyHandler, worker: worker)
let formHotKey = HotKey(formKeys.open) { inputForm.toggle() }
let settingsModel = SettingsModel(keys: formKeys, fontSize: fontSize, punctuation: punctuation, form: inputForm, hotKey: formHotKey)
let settingsWindow = SettingsWindow(model: settingsModel)
let statusMenu = StatusMenu(openKey: formKeys.open, openForm: { inputForm.toggle() }, openSettings: { settingsWindow.show() })
settingsModel.keysChanged = { statusMenu.show(openKey: $0.open) }
inputForm.openSettings = { settingsWindow.show() }

log.notice("Kaede started.")
application.run()
