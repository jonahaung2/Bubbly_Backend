import Foundation
import Vapor

struct FirebaseServiceAccount: Decodable, Sendable {
    let projectID: String
    let privateKeyID: String
    let privateKey: String
    let clientEmail: String
    let tokenURI: URL

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case privateKeyID = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case tokenURI = "token_uri"
    }

    static func load() throws -> FirebaseServiceAccount {
        let data: Data
        if let encoded = Environment.get("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64")?.trimmedNonempty {
            guard let decoded = Data(base64Encoded: encoded) else {
                throw ConfigurationError.invalid("FIREBASE_SERVICE_ACCOUNT_JSON_BASE64")
            }
            data = decoded
        } else if let path = Environment.get("FIREBASE_SERVICE_ACCOUNT_FILE")?.trimmedNonempty {
            let url = URL(fileURLWithPath: path)
            guard url.isFileURL else {
                throw ConfigurationError.invalid("FIREBASE_SERVICE_ACCOUNT_FILE")
            }
            do {
                data = try Data(contentsOf: url, options: [.mappedIfSafe])
            } catch {
                throw ConfigurationError.invalid("FIREBASE_SERVICE_ACCOUNT_FILE")
            }
        } else {
            throw ConfigurationError.missing(
                "FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 or FIREBASE_SERVICE_ACCOUNT_FILE"
            )
        }

        do {
            let credentials = try JSONDecoder().decode(FirebaseServiceAccount.self, from: data)
            guard !credentials.projectID.isEmpty,
                  !credentials.privateKeyID.isEmpty,
                  !credentials.privateKey.isEmpty,
                  !credentials.clientEmail.isEmpty,
                  credentials.tokenURI.scheme?.lowercased() == "https",
                  credentials.tokenURI.host != nil else {
                throw ConfigurationError.invalid("Firebase service account")
            }
            return credentials
        } catch let error as ConfigurationError {
            throw error
        } catch {
            throw ConfigurationError.invalid("Firebase service account")
        }
    }
}

private extension String {
    var trimmedNonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
