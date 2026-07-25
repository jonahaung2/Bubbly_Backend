import Fluent
import Foundation
import Vapor

final class ContactModel: Model, @unchecked Sendable {
    static let schema = "contacts"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "firebase_uid")
    var firebaseUID: String

    @Field(key: "name")
    var name: String

    @Field(key: "mobile")
    var mobile: String

    @Field(key: "push_token")
    var pushToken: String

    @Field(key: "public_key")
    var publicKey: String

    @OptionalField(key: "photo_data")
    var photoData: Data?

    @OptionalField(key: "photo_content_type")
    var photoContentType: String?

    @OptionalField(key: "photo_version")
    var photoVersion: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        firebaseUID: String,
        name: String,
        mobile: String,
        pushToken: String,
        publicKey: String
    ) {
        self.id = id
        self.firebaseUID = firebaseUID
        self.name = name
        self.mobile = mobile
        self.pushToken = pushToken
        self.publicKey = publicKey
    }
}
