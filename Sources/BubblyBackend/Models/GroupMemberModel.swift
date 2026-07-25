import Fluent
import Foundation
import Vapor

final class GroupMemberModel: Model, @unchecked Sendable {
    static let schema = "conversation_group_members"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "group_id")
    var group: GroupModel

    @Field(key: "group_uid")
    var groupUID: String

    @Field(key: "user_id")
    var userID: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        groupID: GroupModel.IDValue,
        groupUID: String,
        userID: String
    ) {
        self.id = id
        $group.id = groupID
        self.groupUID = groupUID
        self.userID = userID
    }
}
