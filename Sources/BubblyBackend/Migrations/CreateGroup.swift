import Fluent
import FluentPostgresDriver

struct CreateGroup: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(GroupModel.schema)
            .id()
            .field("group_uid", .string, .required)
            .field("name", .string, .required)
            .field("photo_url", .string)
            .field("created_by", .string, .required)
            .field("created_date", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "group_uid")
            .create()

        try await database.schema(GroupMemberModel.schema)
            .id()
            .field("group_id", .uuid, .required, .references(GroupModel.schema, "id", onDelete: .cascade))
            .field("group_uid", .string, .required)
            .field("user_id", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "group_id", "user_id")
            .create()

        guard let sql = database as? any SQLDatabase else {
            throw ConfigurationError.invalid("DATABASE_URL")
        }
        try await sql.raw(
            "CREATE INDEX conversation_group_members_user_group_idx ON conversation_group_members (user_id, group_uid)"
        ).run()
        try await sql.raw(
            "CREATE INDEX conversation_groups_created_by_idx ON conversation_groups (created_by)"
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(GroupMemberModel.schema).delete()
        try await database.schema(GroupModel.schema).delete()
    }
}
