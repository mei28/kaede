import Foundation
import KaedeCore

/// The input form's keys from the app's settings (`just form-key`), checked at startup.
enum FormSettings {
    static let openKey = "formOpenKey"
    static let insertKey = "formInsertKey"

    /// Stops Kaede when the settings hold keys it cannot use.
    static func load() -> FormKeys {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [openKey: FormKeys.defaultOpen, insertKey: FormKeys.defaultInsert])
        guard let open = defaults.string(forKey: openKey), let insert = defaults.string(forKey: insertKey) else {
            preconditionFailure("registered defaults are strings")
        }
        do {
            return try FormKeys(open: KeyCombo(parsing: open), insert: KeyCombo(parsing: insert))
        } catch {
            terminate("The form keys in the settings cannot be used (\(openKey) = \(open), \(insertKey) = \(insert)): \(error). Change them with `just form-key`.")
        }
    }
}
