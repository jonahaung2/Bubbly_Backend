import Foundation
import Testing
@testable import BubblyBackend

@Suite
struct ValidationTests {
    @Test
    func acceptsValidE164Numbers() {
        #expect(Validation.isE164("+6591234567"))
        #expect(Validation.isE164("+14155552671"))
    }

    @Test
    func rejectsInvalidPhoneNumbers() {
        #expect(!Validation.isE164("6591234567"))
        #expect(!Validation.isE164("+012345678"))
        #expect(!Validation.isE164("+65 9123 4567"))
        #expect(!Validation.isE164("+٦٥٩١٢٣٤٥٦٧"))
    }

    @Test
    func validatesImageSignatures() {
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let webp = Data("RIFF0000WEBP".utf8)
        #expect(ImagePayloadValidator.isValid(data: png, contentType: "image/png"))
        #expect(ImagePayloadValidator.isValid(data: jpeg, contentType: "image/jpeg"))
        #expect(ImagePayloadValidator.isValid(data: webp, contentType: "image/webp"))
        #expect(!ImagePayloadValidator.isValid(data: png, contentType: "image/jpeg"))
    }

    @Test
    func validatesGroupInput() throws {
        let request = GroupUpsertRequest(
            name: "  Friends  ",
            photoURL: "https://example.com/group.png",
            members: ["owner", "member", "member"]
        )
        let validated = try request.validated(currentUserID: "owner")
        #expect(validated.name == "Friends")
        #expect(validated.members == ["member", "owner"])
    }

    @Test
    func rejectsInvalidGroupInput() {
        #expect(throws: (any Error).self) {
            try GroupUpsertRequest(
                name: "Friends",
                photoURL: "http://example.com/group.png",
                members: ["owner", "member"]
            ).validated(currentUserID: "owner")
        }
        #expect(throws: (any Error).self) {
            try GroupUpsertRequest(
                name: "Friends",
                photoURL: nil,
                members: ["member-one", "member-two"]
            ).validated(currentUserID: "owner")
        }
    }

    @Test
    func validatesPushNotificationInput() throws {
        let request = PushNotificationRequest(
            recipients: [
                .init(userID: " recipient ", messageContent: " encrypted "),
                .init(userID: " recipient ", messageContent: " duplicate "),
                .init(userID: " other ", messageContent: " other-encrypted ")
            ],
            title: " New message ",
            body: " Hello ",
            conversationID: " conversation ",
            deepLink: "bubbly://conversation/one"
        )
        let validated = try request.validated(senderUserID: "sender")
        #expect(validated.recipients.map(\.userID) == ["recipient", "other"])
        #expect(validated.recipients.map(\.messageContent) == ["encrypted", "other-encrypted"])
        #expect(validated.conversationID == "conversation")
    }

    @Test
    func rejectsInvalidPushNotificationInput() {
        #expect(throws: (any Error).self) {
            try PushNotificationRequest(
                recipients: [.init(userID: "sender", messageContent: "encrypted")],
                title: nil,
                body: nil,
                conversationID: "conversation",
                deepLink: nil
            ).validated(senderUserID: "sender")
        }
        #expect(throws: (any Error).self) {
            try PushNotificationRequest(
                recipients: [.init(userID: "recipient", messageContent: "encrypted")],
                title: nil,
                body: nil,
                conversationID: "conversation",
                deepLink: "javascript:alert(1)"
            ).validated(senderUserID: "sender")
        }
    }

    @Test
    func validatesAdminContactInput() throws {
        let request = AdminContactUpdateRequest(
            name: "  Ada Lovelace  ",
            mobile: "+14155552671",
            publicKey: "public-key"
        )
        let validated = try request.validated()
        #expect(validated.name == "Ada Lovelace")
        #expect(validated.mobile == "+14155552671")
    }

    @Test
    func rejectsInvalidAdminContactInput() {
        #expect(throws: (any Error).self) {
            try AdminContactUpdateRequest(
                name: "   ",
                mobile: "not-a-phone-number",
                publicKey: "public-key"
            ).validated()
        }
    }

    @Test
    func validatesAdminGroupInput() throws {
        let request = AdminGroupUpdateRequest(
            name: "  Operations  ",
            photoURL: "https://example.com/group.png",
            members: ["second", "first", "second"]
        )
        let validated = try request.validated()
        #expect(validated.name == "Operations")
        #expect(validated.members == ["first", "second"])
    }

    @Test
    func rejectsInsecureAdminGroupPhotoURL() {
        #expect(throws: (any Error).self) {
            try AdminGroupUpdateRequest(
                name: "Operations",
                photoURL: "http://example.com/group.png",
                members: ["member"]
            ).validated()
        }
    }

    @Test
    func validatesAdminPageRequests() throws {
        let cursor = UUID()
        let defaultPage = try AdminPageRequest(cursorValue: nil, requestedLimit: nil)
        let maximumPage = try AdminPageRequest(
            cursorValue: cursor.uuidString,
            requestedLimit: 10_000
        )
        let minimumPage = try AdminPageRequest(cursorValue: nil, requestedLimit: -10)
        #expect(defaultPage.limit == AdminPageRequest.defaultLimit)
        #expect(maximumPage.cursor == cursor)
        #expect(maximumPage.limit == AdminPageRequest.maximumLimit)
        #expect(minimumPage.limit == 1)
    }

    @Test
    func rejectsInvalidAdminPageCursor() {
        #expect(throws: (any Error).self) {
            try AdminPageRequest(cursorValue: "invalid", requestedLimit: 100)
        }
    }
}
