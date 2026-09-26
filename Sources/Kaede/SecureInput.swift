import Carbon

/// True while a password field or a password manager (1Password, Keychain Access) holds secure input.
enum SecureInput {
    static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
