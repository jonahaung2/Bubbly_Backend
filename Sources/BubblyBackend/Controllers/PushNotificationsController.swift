import Fluent
import Vapor

struct PushNotificationsController: RouteCollection {
    private struct Delivery: Sendable {
        let result: PushNotificationResponse.Result
        let invalidPushToken: String?
    }

    func boot(routes: any RoutesBuilder) throws {
        routes.post("v1", "push-notifications", use: send)
    }

    private func send(request: Request) async throws -> PushNotificationResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let notification = try request.content
            .decode(PushNotificationRequest.self)
            .validated(senderUserID: principal.userID)
        let userIDs = notification.recipients.map(\.userID)
        let contacts = try await ContactModel.query(on: request.db)
            .filter(\.$firebaseUID ~~ userIDs)
            .all()
        let tokensByUserID = Dictionary(uniqueKeysWithValues: contacts.map {
            ($0.firebaseUID, $0.pushToken.trimmingCharacters(in: .whitespacesAndNewlines))
        })
        let sender = request.application.pushNotificationSender
        let client = request.client
        let results = try await withThrowingTaskGroup(
            of: Delivery.self,
            returning: [Delivery].self
        ) { group in
            for recipient in notification.recipients {
                group.addTask {
                    guard let pushToken = tokensByUserID[recipient.userID],
                          !pushToken.isEmpty, pushToken.count <= 4_096 else {
                        return Delivery(
                            result: .init(
                                recipientUserID: recipient.userID,
                                messageID: nil,
                                failureCode: "missing_push_token"
                            ),
                            invalidPushToken: nil
                        )
                    }
                    do {
                        let messageID = try await sender.send(
                            notification,
                            recipient: recipient,
                            deviceToken: pushToken,
                            client: client
                        )
                        return Delivery(
                            result: .init(
                                recipientUserID: recipient.userID,
                                messageID: messageID,
                                failureCode: nil
                            ),
                            invalidPushToken: nil
                        )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch FirebasePushNotificationError.invalidDeviceToken {
                        return Delivery(
                            result: .init(
                                recipientUserID: recipient.userID,
                                messageID: nil,
                                failureCode: "invalid_push_token"
                            ),
                            invalidPushToken: pushToken
                        )
                    } catch {
                        return Delivery(
                            result: .init(
                                recipientUserID: recipient.userID,
                                messageID: nil,
                                failureCode: "fcm_send_failed"
                            ),
                            invalidPushToken: nil
                        )
                    }
                }
            }
            var results: [Delivery] = []
            results.reserveCapacity(notification.recipients.count)
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.result.recipientUserID < $1.result.recipientUserID }
        }
        for delivery in results {
            guard let invalidPushToken = delivery.invalidPushToken else {
                continue
            }
            try await ContactRepository.clearPushToken(
                userID: delivery.result.recipientUserID,
                matching: invalidPushToken,
                on: request.db
            )
        }
        return PushNotificationResponse(results: results.map(\.result))
    }
}
