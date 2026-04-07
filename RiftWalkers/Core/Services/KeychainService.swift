import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.riftwalkers.app"

    private init() {}

    // MARK: - Token Storage

    func saveTokens(access: String, refresh: String) {
        save(key: "access_token", value: access)
        save(key: "refresh_token", value: refresh)
    }

    func getAccessToken() -> String? {
        load(key: "access_token")
    }

    func getRefreshToken() -> String? {
        load(key: "refresh_token")
    }

    func savePlayerID(_ id: String) {
        save(key: "player_id", value: id)
    }

    func getPlayerID() -> String? {
        load(key: "player_id")
    }

    func clearAll() {
        delete(key: "access_token")
        delete(key: "refresh_token")
        delete(key: "player_id")
    }

    // MARK: - Private

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
