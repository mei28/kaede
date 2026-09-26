import Foundation
import Security

public enum KeychainError: Error, Equatable {
    /// Reading the item failed for a reason other than its absence.
    case unreadable(service: String, status: OSStatus)
}

/// API keys stored as generic passwords `com.mei28.kaede.<name>` by `just set-key <name>`.
public enum Keychain {
    /// The key, or nil when none is stored.
    public static func apiKey(named name: String) throws -> String? {
        let service = "com.mei28.kaede.\(name)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unreadable(service: service, status: status)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
