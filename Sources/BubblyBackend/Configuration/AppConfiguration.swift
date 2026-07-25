import Foundation
import Vapor

struct AppConfiguration: Sendable {
    let firebaseProjectID: String
    let firebaseServiceAccount: FirebaseServiceAccount
    let publicBaseURL: URL

    static func load(environment: Environment) throws -> AppConfiguration {
        guard let firebaseProjectID = Environment.get("FIREBASE_PROJECT_ID")?.trimmedNonempty else {
            throw ConfigurationError.missing("FIREBASE_PROJECT_ID")
        }
        let firebaseServiceAccount = try FirebaseServiceAccount.load()
        guard firebaseServiceAccount.projectID == firebaseProjectID else {
            throw ConfigurationError.invalid("Firebase service-account project_id")
        }
        guard let publicBaseURLString = Environment.get("PUBLIC_BASE_URL")?.trimmedNonempty,
              let publicBaseURL = URL(string: publicBaseURLString),
              let scheme = publicBaseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              publicBaseURL.host != nil else {
            throw ConfigurationError.invalid("PUBLIC_BASE_URL")
        }
        if environment == .production, publicBaseURL.scheme != "https" {
            throw ConfigurationError.insecurePublicURL
        }
        return AppConfiguration(
            firebaseProjectID: firebaseProjectID,
            firebaseServiceAccount: firebaseServiceAccount,
            publicBaseURL: publicBaseURL
        )
    }
}

enum ConfigurationError: Error, CustomStringConvertible {
    case missing(String)
    case invalid(String)
    case insecurePublicURL

    var description: String {
        switch self {
        case let .missing(key):
            "Missing required environment variable: \(key)"
        case let .invalid(key):
            "Invalid environment variable: \(key)"
        case .insecurePublicURL:
            "PUBLIC_BASE_URL must use HTTPS in production"
        }
    }
}

private extension String {
    var trimmedNonempty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
