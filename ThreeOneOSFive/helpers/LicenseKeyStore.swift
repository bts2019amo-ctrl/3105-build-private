import Foundation
import Security

struct StoredLicense: Codable {
    let key: String
    let expiresAt: TimeInterval
    let daysLeft: Int
}

enum LicenseKeyStore {
    private static let service = "com.apple.mobile.MobileHouseArrest.proxy-license"
    private static let account = "active-license"

    static func load() -> StoredLicense? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredLicense.self, from: data)
    }

    @discardableResult
    static func save(key: String, expiresAt: TimeInterval, daysLeft: Int) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, expiresAt > 0,
              let data = try? JSONEncoder().encode(StoredLicense(key: trimmed, expiresAt: expiresAt, daysLeft: max(0, daysLeft))) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        _ = SecItemDelete(query as CFDictionary)
    }

    /// Migrates the pre-existing UserDefaults license and restores the Keychain value after reinstall.
    static func restoreToUserDefaults() {
        let defaults = UserDefaults.standard
        if let stored = load() {
            defaults.set(stored.key, forKey: "proxy_access_key")
            defaults.set(stored.daysLeft, forKey: "proxy_days_left")
            defaults.set(stored.expiresAt, forKey: "proxy_key_expires_at")
            defaults.set(stored.key, forKey: "proxy_key_expiration_anchor")
            return
        }

        let key = defaults.string(forKey: "proxy_access_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let expiresAt = defaults.double(forKey: "proxy_key_expires_at")
        guard !key.isEmpty, expiresAt > 0 else { return }
        let daysLeft = defaults.integer(forKey: "proxy_days_left")
        _ = save(key: key, expiresAt: expiresAt, daysLeft: daysLeft)
    }
}
