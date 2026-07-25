import Foundation
import Vapor

struct PushNotificationRequest: Content, Sendable {
    let recipients: [Recipient]
    let title: String?
    let body: String?
    let conversationID: String
    let deepLink: String?

    struct Recipient: Content, Sendable {
        let userID: String
        let messageContent: String
    }

    func validated(senderUserID: String) throws -> PushNotificationRequest {
        let conversationID = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let deepLink = deepLink?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !recipients.isEmpty, recipients.count <= 256,
              !conversationID.isEmpty, conversationID.count <= 128,
              title?.count ?? 0 <= 100,
              body?.count ?? 0 <= 4_096 else {
            throw Abort(.badRequest, reason: "Push notification contains invalid values")
        }
        var seen = Set<String>()
        let recipients = try recipients.compactMap { recipient -> Recipient? in
            let userID = recipient.userID.trimmingCharacters(in: .whitespacesAndNewlines)
            let messageContent = recipient.messageContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard userID != senderUserID,
                  !userID.isEmpty, userID.count <= 128,
                  !messageContent.isEmpty, messageContent.utf8.count <= 32_768 else {
                throw Abort(.badRequest, reason: "Push notification recipient contains invalid values")
            }
            guard seen.insert(userID).inserted else {
                return nil
            }
            return Recipient(userID: userID, messageContent: messageContent)
        }
        if let deepLink, !deepLink.isEmpty {
            guard deepLink.count <= 2_048,
                  let url = URL(string: deepLink),
                  let scheme = url.scheme?.lowercased(),
                  ["bubbly", "https"].contains(scheme) else {
                throw Abort(.badRequest, reason: "Push notification deep link is invalid")
            }
        }
        return PushNotificationRequest(
            recipients: recipients,
            title: title?.isEmpty == true ? nil : title,
            body: body?.isEmpty == true ? nil : body,
            conversationID: conversationID,
            deepLink: deepLink?.isEmpty == true ? nil : deepLink
        )
    }
}

struct PushNotificationResponse: Content, Sendable {
    let results: [Result]

    struct Result: Content, Sendable {
        let recipientUserID: String
        let messageID: String?
        let failureCode: String?
    }
}
