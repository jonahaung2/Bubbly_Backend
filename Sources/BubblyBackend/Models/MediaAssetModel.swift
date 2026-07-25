import Fluent
import Foundation

final class MediaAssetModel: Model, @unchecked Sendable {
    static let schema = "media_assets"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "kind")
    var kind: String

    @Field(key: "scope_id")
    var scopeID: String

    @Field(key: "asset_id")
    var assetID: String

    @Field(key: "owner_user_id")
    var ownerUserID: String

    @Field(key: "data")
    var data: Data

    @Field(key: "content_type")
    var contentType: String

    @Field(key: "version")
    var version: UUID

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        kind: String,
        scopeID: String,
        assetID: String,
        ownerUserID: String,
        data: Data,
        contentType: String,
        version: UUID
    ) {
        self.id = id
        self.kind = kind
        self.scopeID = scopeID
        self.assetID = assetID
        self.ownerUserID = ownerUserID
        self.data = data
        self.contentType = contentType
        self.version = version
    }
}
