import Foundation
import Security

struct SecureSessionStore {
    private let service = "br.com.prefeitura.requisiplus.auth"
    private let account = "current_session"

    func save(_ session: UserSession) throws {
        let data = try JSONEncoder().encode(session)
        let query = baseQuery()

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecureSessionStoreError.unexpectedStatus(status)
        }
    }

    func load() throws -> UserSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw SecureSessionStoreError.invalidData
            }
            return try JSONDecoder().decode(UserSession.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw SecureSessionStoreError.unexpectedStatus(status)
        }
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum SecureSessionStoreError: LocalizedError {
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Não foi possível ler a sessão armazenada."
        case .unexpectedStatus(let status):
            return "Falha ao acessar o armazenamento seguro (\(status))."
        }
    }
}
