import Foundation
import Security

public enum KeychainError: Error, Equatable {
    /// Reading the item failed for a reason other than its absence.
    case unreadable(service: String, status: OSStatus)
    /// Storing the item failed.
    case unwritable(service: String, status: OSStatus)
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

    /// Stores the key as `just set-key` does (account "kaede"), replacing one already there.
    public static func setAPIKey(_ key: String, named name: String) throws {
        let service = "com.mei28.kaede.\(name)"
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "kaede",
        ]
        let value = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(item as CFDictionary, value as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(item.merging(value) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.unwritable(service: service, status: status)
        }
    }
}
