import Fluent
import Foundation
import Vapor

final class GroupModel: Model, @unchecked Sendable {
    static let schema = "conversation_groups"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "group_uid")
    var groupUID: String

    @Field(key: "name")
    var name: String

    @OptionalField(key: "photo_url")
    var photoURL: String?

    @Field(key: "created_by")
    var createdBy: String

    @Field(key: "created_date")
    var createdDate: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$group)
    var memberships: [GroupMemberModel]

    init() {}

    init(
        id: UUID? = nil,
        groupUID: String,
        name: String,
        photoURL: String?,
        createdBy: String,
        createdDate: Date
    ) {
        self.id = id
        self.groupUID = groupUID
        self.name = name
        self.photoURL = photoURL
        self.createdBy = createdBy
        self.createdDate = createdDate
    }
}
