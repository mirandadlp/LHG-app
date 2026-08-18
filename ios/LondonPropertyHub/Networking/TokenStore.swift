import Foundation
import Security

/// The API token lives in the Keychain, not UserDefaults.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` means the token survives
/// a reboot once the phone has been unlocked, is never written to an iCloud or
/// iTunes backup, and never follows the user to a new device.
struct TokenStore {

    private let service = "uk.co.londonhotelgroup.propertyhub.token"
    private let account = "api-token"

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }

        // Delete first: SecItemAdd fails rather than overwrites.
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?

        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data,
            let token = String(data: data, encoding: .utf8),
            !token.isEmpty
        else {
            return nil
        }

        return token
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
