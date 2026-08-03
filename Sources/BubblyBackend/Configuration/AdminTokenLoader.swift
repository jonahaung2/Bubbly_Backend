import Foundation
import Vapor

#if canImport(Security)
import Security
#endif

enum AdminTokenLoader {
    static func load(environment: Environment) throws -> String? {
        if let token = Environment.get("ADMIN_API_TOKEN")?.trimmedNonempty {
            return token
        }
        guard environment != .production else {
            return nil
        }
        return developmentKeychainToken()
    }

    private static func developmentKeychainToken() -> String? {
        #if canImport(Security) && os(macOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.bubbly.admin",
            kSecAttrAccount as String: "admin-api-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)?.trimmedNonempty else {
            return nil
        }
        return token
        #else
        return nil
        #endif
    }
}

private extension String {
    var trimmedNonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
