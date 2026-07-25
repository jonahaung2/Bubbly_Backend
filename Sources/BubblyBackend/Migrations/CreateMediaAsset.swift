import Fluent
import FluentPostgresDriver

struct CreateMediaAsset: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(MediaAssetModel.schema)
            .id()
            .field("kind", .string, .required)
            .field("scope_id", .string, .required)
            .field("asset_id", .string, .required)
            .field("owner_user_id", .string, .required)
            .field("data", .data, .required)
            .field("content_type", .string, .required)
            .field("version", .uuid, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "kind", "scope_id", "asset_id")
            .create()

        guard let sql = database as? any SQLDatabase else {
            throw ConfigurationError.invalid("DATABASE_URL")
        }
        try await sql.raw(
            "CREATE INDEX media_assets_owner_idx ON media_assets (owner_user_id)"
        ).run()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(MediaAssetModel.schema).delete()
    }
}
