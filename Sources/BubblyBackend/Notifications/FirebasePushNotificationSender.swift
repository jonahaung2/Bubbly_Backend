import Foundation
import JWTKit
import Vapor

enum FirebasePushNotificationError: Error, Equatable {
    case invalidDeviceToken
    case rejected
}

actor FirebasePushNotificationSender {
    private struct OAuthPayload: JWTPayload {
        let iss: IssuerClaim
        let scope: String
        let aud: AudienceClaim
        let exp: ExpirationClaim
        let iat: IssuedAtClaim

        func verify(using _: some JWTAlgorithm) async throws {
            try exp.verifyNotExpired()
        }
    }

    private struct OAuthResponse: Decodable {
        let accessToken: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
        }
    }

    private struct FCMRequest: Encodable {
        let message: Message

        struct Message: Encodable {
            let token: String
            let data: [String: String]
            let apns: APNS
        }

        struct APNS: Encodable {
            let payload: Payload
        }

        struct Payload: Encodable {
            let aps: APS
        }

        struct APS: Encodable {
            let alert: Alert
            let badge: Int
            let sound: String
            let contentAvailable: Int
            let mutableContent: Int
            let interruptionLevel: String

            enum CodingKeys: String, CodingKey {
                case alert
                case badge
                case sound
                case contentAvailable = "content-available"
                case mutableContent = "mutable-content"
                case interruptionLevel = "interruption-level"
            }
        }

        struct Alert: Encodable {
            let title: String?
            let body: String?
        }
    }

    private struct FCMResponse: Decodable {
        let name: String
    }

    struct FCMErrorResponse: Decodable {
        let error: Failure

        struct Failure: Decodable {
            let status: String?
            let details: [Detail]?
        }

        struct Detail: Decodable {
            let errorCode: String?
        }

        var isPermanentDeviceTokenFailure: Bool {
            let detailCodes = (error.details ?? []).compactMap(\.errorCode)
            return error.status == "UNREGISTERED"
                || detailCodes.contains("UNREGISTERED")
                || detailCodes.contains("INVALID_ARGUMENT")
        }
    }

    private let credentials: FirebaseServiceAccount
    private var accessToken: String?
    private var accessTokenExpiration = Date.distantPast

    init(credentials: FirebaseServiceAccount) {
        self.credentials = credentials
    }

    func send(
        _ notification: PushNotificationRequest,
        recipient: PushNotificationRequest.Recipient,
        deviceToken: String,
        client: any Client
    ) async throws -> String {
        let token = try await validAccessToken(client: client)
        let endpoint = URI(
            string: "https://fcm.googleapis.com/v1/projects/\(credentials.projectID)/messages:send"
        )
        let payload = FCMRequest(
            message: .init(
                token: deviceToken,
                data: [
                    "message": recipient.messageContent,
                    "con_id": notification.conversationID,
                    "deep_link": notification.deepLink ?? ""
                ],
                apns: .init(
                    payload: .init(
                        aps: .init(
                            alert: .init(title: notification.title, body: notification.body),
                            badge: 1,
                            sound: "drip.flat.m4a",
                            contentAvailable: 1,
                            mutableContent: 1,
                            interruptionLevel: "time-sensitive"
                        )
                    )
                )
            )
        )
        let response = try await client.post(endpoint) { request in
            request.headers.bearerAuthorization = .init(token: token)
            try request.content.encode(payload, as: .json)
        }
        guard response.status == .ok else {
            if response.status == .unauthorized {
                accessToken = nil
                accessTokenExpiration = .distantPast
            }
            if let failure = try? response.content.decode(FCMErrorResponse.self),
               failure.isPermanentDeviceTokenFailure {
                throw FirebasePushNotificationError.invalidDeviceToken
            }
            throw FirebasePushNotificationError.rejected
        }
        let model = try response.content.decode(FCMResponse.self)
        guard let messageID = model.name.split(separator: "/").last, !messageID.isEmpty else {
            throw Abort(.badGateway, reason: "Firebase returned an invalid response")
        }
        return String(messageID)
    }

    private func validAccessToken(client: any Client) async throws -> String {
        if let accessToken, accessTokenExpiration > Date.now.addingTimeInterval(60) {
            return accessToken
        }
        let issuedAt = Date.now
        let keys = JWTKeyCollection()
        await keys.add(
            rsa: try Insecure.RSA.PrivateKey(pem: credentials.privateKey),
            digestAlgorithm: .sha256,
            kid: .init(string: credentials.privateKeyID)
        )
        let assertion = try await keys.sign(
            OAuthPayload(
                iss: .init(value: credentials.clientEmail),
                scope: "https://www.googleapis.com/auth/firebase.messaging",
                aud: .init(value: [credentials.tokenURI.absoluteString]),
                exp: .init(value: issuedAt.addingTimeInterval(3_600)),
                iat: .init(value: issuedAt)
            ),
            kid: .init(string: credentials.privateKeyID)
        )
        var components = URLComponents()
        components.queryItems = [
            .init(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            .init(name: "assertion", value: assertion)
        ]
        guard let body = components.percentEncodedQuery else {
            throw Abort(.internalServerError)
        }
        let response = try await client.post(URI(string: credentials.tokenURI.absoluteString)) { request in
            request.headers.contentType = .urlEncodedForm
            request.body = .init(string: body)
        }
        guard response.status == .ok else {
            throw Abort(.badGateway, reason: "Firebase authentication failed")
        }
        let oauth = try response.content.decode(OAuthResponse.self)
        guard !oauth.accessToken.isEmpty, oauth.expiresIn > 0 else {
            throw Abort(.badGateway, reason: "Firebase authentication returned an invalid response")
        }
        accessToken = oauth.accessToken
        accessTokenExpiration = issuedAt.addingTimeInterval(TimeInterval(oauth.expiresIn))
        return oauth.accessToken
    }
}
