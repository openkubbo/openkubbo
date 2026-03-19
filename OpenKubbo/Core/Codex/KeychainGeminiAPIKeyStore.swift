import Foundation
import Security

final class KeychainGeminiAPIKeyStore: GeminiAPIKeyStoring {
    private let service: String
    private let account: String

    init(service: String = "tarik.OpenKubbo.gemini", account: String = "api-key") {
        self.service = service
        self.account = account
    }

    func apiKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return apiKey
    }

    func save(apiKey: String) {
        let data = Data(apiKey.utf8)
        let attributes = [kSecValueData as String: data]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
