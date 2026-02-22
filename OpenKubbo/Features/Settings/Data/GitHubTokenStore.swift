import Foundation
import Security

protocol GitHubTokenStoring {
    func token() -> String?
    func save(token: String)
    func clear()
}

final class KeychainGitHubTokenStore: GitHubTokenStoring {
    private let service: String
    private let account: String

    init(service: String = "tarik.OpenKubbo.github", account: String = "oauth-token") {
        self.service = service
        self.account = account
    }

    func token() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return token
    }

    func save(token: String) {
        let data = Data(token.utf8)
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
