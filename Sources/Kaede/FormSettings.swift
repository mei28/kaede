import Foundation
import KaedeCore

/// The input form's settings in the app's defaults (the settings panel, `just form-key`).
enum FormSettings {
    static let openKey = "formOpenKey"
    static let insertKey = "formInsertKey"
    static let fontSize = "formFontSize"
    static let defaultFontSize = 15.0
    static let fontSizes = 12.0...28.0
    static let punctuation = "formPunctuation"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            openKey: FormKeys.defaultOpen, insertKey: FormKeys.defaultInsert, fontSize: defaultFontSize,
            punctuation: PunctuationStyle.touten.rawValue,
        ])
    }

    /// Stops Kaede when the settings hold keys it cannot use.
    static func load() -> FormKeys {
        let defaults = UserDefaults.standard
        guard let open = defaults.string(forKey: openKey), let insert = defaults.string(forKey: insertKey) else {
            preconditionFailure("registered defaults are strings")
        }
        do {
            return try FormKeys(open: KeyCombo(parsing: open), insert: KeyCombo(parsing: insert))
        } catch {
            terminate("The form keys in the settings cannot be used (\(openKey) = \(open), \(insertKey) = \(insert)): \(error). Change them with `just form-key`.")
        }
    }

    static func save(_ keys: FormKeys) {
        UserDefaults.standard.set(keys.open.description, forKey: openKey)
        UserDefaults.standard.set(keys.insert.description, forKey: insertKey)
    }

    /// Stops Kaede when the size is out of range, as a hand-written default could be.
    static func loadFontSize() -> Double {
        let size = UserDefaults.standard.double(forKey: fontSize)
        guard fontSizes.contains(size) else {
            terminate("The form's font size \(size) is outside \(fontSizes).")
        }
        return size
    }

    static func save(fontSize size: Double) {
        UserDefaults.standard.set(size, forKey: fontSize)
    }

    /// Stops Kaede when the setting names no pair, as a hand-written default could.
    static func loadPunctuation() -> PunctuationStyle {
        let pair = UserDefaults.standard.string(forKey: punctuation)
        guard let pair, let style = PunctuationStyle(rawValue: pair) else {
            terminate("The form's punctuation \(pair ?? "nil") is none of \(PunctuationStyle.allCases.map(\.rawValue)).")
        }
        return style
    }

    static func save(punctuation style: PunctuationStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: punctuation)
    }
}
