import Foundation
import JWTKit
import Vapor

actor FirebaseTokenVerifier {
    private let projectID: String
    private let keysURL = URI(string: "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
    private var keys: JWTKeyCollection?
    private var keyIdentifiers: Set<String> = []
    private var expiration = Date.distantPast
    private var lastRefresh = Date.distantPast

    init(projectID: String) {
        self.projectID = projectID
    }

    func verify(_ token: String, client: any Client) async throws -> FirebasePrincipal {
        let header = try tokenHeader(token)
        guard header.algorithm == "RS256", !header.keyIdentifier.isEmpty else {
            throw Abort(.unauthorized)
        }
        let keyIdentifier = header.keyIdentifier
        let keyCollection = try await currentKeys(keyIdentifier: keyIdentifier, client: client)
        guard keyIdentifiers.contains(keyIdentifier) else {
            throw Abort(.unauthorized)
        }
        let payload = try await keyCollection.verify(token, as: FirebaseTokenPayload.self)

        guard payload.issuer.value == "https://securetoken.google.com/\(projectID)" else {
            throw Abort(.unauthorized)
        }
        try payload.audience.verifyIntendedAudience(includes: projectID)
        guard payload.issuedAt.value <= Date.now.addingTimeInterval(30),
              Date(timeIntervalSince1970: TimeInterval(payload.authTime)) <= Date.now.addingTimeInterval(30) else {
            throw Abort(.unauthorized)
        }
        return FirebasePrincipal(userID: payload.subject.value)
    }

    private func tokenHeader(_ token: String) throws -> TokenHeader {
        guard let segment = token.split(separator: ".", omittingEmptySubsequences: false).first,
              segment.count <= 4_096 else {
            throw Abort(.unauthorized)
        }
        var encoded = String(segment)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded.append(String(repeating: "=", count: (4 - encoded.count % 4) % 4))
        guard let data = Data(base64Encoded: encoded) else {
            throw Abort(.unauthorized)
        }
        do {
            return try JSONDecoder().decode(TokenHeader.self, from: data)
        } catch {
            throw Abort(.unauthorized)
        }
    }

    private func currentKeys(keyIdentifier: String, client: any Client) async throws -> JWTKeyCollection {
        if let keys, expiration > Date.now {
            if keyIdentifiers.contains(keyIdentifier) {
                return keys
            }
            guard lastRefresh < Date.now.addingTimeInterval(-300) else {
                throw Abort(.unauthorized)
            }
        }
        return try await refreshKeys(client: client)
    }

    private func refreshKeys(client: any Client) async throws -> JWTKeyCollection {
        let response = try await client.get(keysURL)
        guard response.status == .ok, let body = response.body else {
            throw Abort(.serviceUnavailable)
        }
        let data = Data(body.readableBytesView)
        guard let json = String(data: data, encoding: .utf8) else {
            throw Abort(.serviceUnavailable)
        }
        let keySet = try JSONDecoder().decode(JWKS.self, from: data)
        let keyCollection = JWTKeyCollection()
        try await keyCollection.add(jwksJSON: json)
        keys = keyCollection
        keyIdentifiers = Set(keySet.keys.compactMap { $0.keyIdentifier?.string })
        lastRefresh = .now
        expiration = Date.now.addingTimeInterval(cacheLifetime(from: response.headers))
        return keyCollection
    }

    private func cacheLifetime(from headers: HTTPHeaders) -> TimeInterval {
        guard let cacheControl = headers.first(name: .cacheControl) else {
            return 3_600
        }
        for directive in cacheControl.split(separator: ",") {
            let components = directive.split(separator: "=", maxSplits: 1)
            if components.count == 2,
               components[0].trimmingCharacters(in: .whitespaces).lowercased() == "max-age",
               let seconds = TimeInterval(components[1].trimmingCharacters(in: .whitespaces)) {
                return max(300, min(seconds, 86_400))
            }
        }
        return 3_600
    }
}

private struct TokenHeader: Decodable {
    let algorithm: String
    let keyIdentifier: String

    enum CodingKeys: String, CodingKey {
        case algorithm = "alg"
        case keyIdentifier = "kid"
    }
}
