import Fluent
import FluentPostgresDriver

struct CreateContact: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ContactModel.schema)
            .id()
            .field("firebase_uid", .string, .required)
            .field("name", .string, .required)
            .field("mobile", .string, .required)
            .field("push_token", .string, .required)
            .field("public_key", .string, .required)
            .field("photo_data", .data)
            .field("photo_content_type", .string)
            .field("photo_version", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "firebase_uid")
            .create()
        guard let sqlDatabase = database as? any SQLDatabase else {
            throw ConfigurationError.invalid("DATABASE_URL")
        }
        try await sqlDatabase.raw("CREATE INDEX contacts_mobile_idx ON contacts (mobile)").run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ContactModel.schema).delete()
    }
}
