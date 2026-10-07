import AppKit
import KaedeCore

Startup.verify()
FormSettings.registerDefaults()
let formKeys = FormSettings.load()
let fontSize = FormSettings.loadFontSize()
// Windows, menus and event monitors need the application object; NSApp stays nil until it is made
let application = NSApplication.shared

let keyHandler = FormKeyHandler()
keyHandler.start()

InputForm.installEditMenu()
let inputForm = InputForm(keys: formKeys, fontSize: fontSize, handler: keyHandler)
let formHotKey = HotKey(formKeys.open) { inputForm.toggle() }
let settingsModel = SettingsModel(keys: formKeys, fontSize: fontSize, form: inputForm, hotKey: formHotKey)
let settingsWindow = SettingsWindow(model: settingsModel)
let statusMenu = StatusMenu(openKey: formKeys.open, openForm: { inputForm.toggle() }, openSettings: { settingsWindow.show() })
settingsModel.keysChanged = { statusMenu.show(openKey: $0.open) }
inputForm.openSettings = { settingsWindow.show() }

log.notice("Kaede started.")
application.run()
