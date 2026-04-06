import Foundation
import Security

public protocol ProfileSecretsStoring {
    func loadSecret(id: UUID) throws -> Data
    func saveSecret(_ data: Data, for id: UUID) throws
    func deleteSecret(id: UUID) throws
}

public final class KeychainSecretsStore: ProfileSecretsStoring {
    public let service: String

    public init(service: String = "dev.codex-account-hub.profile") {
        self.service = service
    }

    public func loadSecret(id: UUID) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw CodexAuthCoreError.keychain(errSecInternalError)
            }
            return data
        case errSecItemNotFound:
            throw CodexAuthCoreError.secretNotFound(id)
        default:
            throw CodexAuthCoreError.keychain(status)
        }
    }

    public func saveSecret(_ data: Data, for id: UUID) throws {
        let account = id.uuidString
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw CodexAuthCoreError.keychain(updateStatus)
        }

        var addQuery = baseQuery
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CodexAuthCoreError.keychain(addStatus)
        }
    }

    public func deleteSecret(id: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CodexAuthCoreError.keychain(status)
        }
    }
}
