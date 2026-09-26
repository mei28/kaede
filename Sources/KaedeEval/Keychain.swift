import Foundation
import Security

/// API keys stored as generic passwords by `just set-key <name>`.
enum Keychain {
    static func apiKey(named name: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mei28.kaede.\(name)",
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status == errSecItemNotFound {
                fail("no \(name) API key in the keychain; store it with `just set-key \(name)`")
            }
            fail("could not read the \(name) API key from the keychain (OSStatus \(status))")
        }
        return String(decoding: data, as: UTF8.self)
    }
}
