import Foundation
import Security

protocol KeychainStoring {
    func save(_ value: String, service: String, account: String) throws
    func read(service: String, account: String) throws -> String?
}

struct KeychainService: KeychainStoring {
    func save(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        var insertQuery = query
        insertQuery[kSecValueData as String] = data

        let status = SecItemAdd(insertQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychain(message: "Could not store API key in Keychain (status \(status)).")
        }
    }

    func read(service: String, account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AppError.keychain(message: "Could not read API key from Keychain (status \(status)).")
        }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw AppError.keychain(message: "Could not decode Keychain value.")
        }
        return value
    }
}
