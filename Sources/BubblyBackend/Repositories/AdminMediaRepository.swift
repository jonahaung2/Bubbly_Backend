import Fluent
import FluentPostgresDriver
import Foundation
import Vapor

enum AdminMediaRepository {
    static func list(
        page: AdminPageRequest,
        publicBaseURL: URL,
        on database: any Database
    ) async throws -> AdminPage<AdminMediaResponse> {
        let records = try await metadata(page: page, on: database)
        let hasNextPage = records.count > page.limit
        let visibleRecords = hasNextPage ? Array(records.prefix(page.limit)) : records
        return AdminPage(
            items: visibleRecords.map { response(record: $0, publicBaseURL: publicBaseURL) },
            nextCursor: hasNextPage ? visibleRecords.last?.id : nil
        )
    }

    static func update(
        id: UUID,
        upload: ImageUpload,
        publicBaseURL: URL,
        on database: any Database
    ) async throws -> AdminMediaResponse {
        let model = try await find(id: id, on: database)
        model.data = upload.data
        model.contentType = upload.contentType
        model.version = UUID()
        try await model.update(on: database)
        return try response(model: model, publicBaseURL: publicBaseURL)
    }

    static func delete(id: UUID, on database: any Database) async throws {
        try await find(id: id, on: database).delete(on: database)
    }

    private static func metadata(
        page: AdminPageRequest,
        on database: any Database
    ) async throws -> [AdminMediaRecord] {
        guard let sql = database as? any SQLDatabase else {
            throw Abort(.internalServerError)
        }
        if let cursor = page.cursor {
            return try await sql.raw(
                """
                SELECT id, kind, scope_id, asset_id, owner_user_id, content_type,
                    OCTET_LENGTH(data) AS byte_count, version, created_at, updated_at
                FROM media_assets
                WHERE id > \(bind: cursor)
                ORDER BY id ASC
                LIMIT \(bind: page.limit + 1)
                """
            ).all(decoding: AdminMediaRecord.self)
        }
        return try await sql.raw(
            """
            SELECT id, kind, scope_id, asset_id, owner_user_id, content_type,
                OCTET_LENGTH(data) AS byte_count, version, created_at, updated_at
            FROM media_assets
            ORDER BY id ASC
            LIMIT \(bind: page.limit + 1)
            """
        ).all(decoding: AdminMediaRecord.self)
    }

    private static func find(id: UUID, on database: any Database) async throws -> MediaAssetModel {
        guard let model = try await MediaAssetModel.find(id, on: database) else {
            throw Abort(.notFound)
        }
        return model
    }

    private static func response(
        record: AdminMediaRecord,
        publicBaseURL: URL
    ) -> AdminMediaResponse {
        AdminMediaResponse(
            id: record.id,
            kind: record.kind,
            scopeID: record.scopeID,
            assetID: record.assetID,
            ownerUserID: record.ownerUserID,
            contentType: record.contentType,
            byteCount: record.byteCount,
            url: mediaURL(
                kind: record.kind,
                scopeID: record.scopeID,
                assetID: record.assetID,
                version: record.version,
                publicBaseURL: publicBaseURL
            ),
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    private static func response(
        model: MediaAssetModel,
        publicBaseURL: URL
    ) throws -> AdminMediaResponse {
        AdminMediaResponse(
            id: try model.requireID(),
            kind: model.kind,
            scopeID: model.scopeID,
            assetID: model.assetID,
            ownerUserID: model.ownerUserID,
            contentType: model.contentType,
            byteCount: model.data.count,
            url: mediaURL(
                kind: model.kind,
                scopeID: model.scopeID,
                assetID: model.assetID,
                version: model.version,
                publicBaseURL: publicBaseURL
            ),
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    private static func mediaURL(
        kind: String,
        scopeID: String,
        assetID: String,
        version: UUID,
        publicBaseURL: URL
    ) -> String {
        ["v1", "media", kind, scopeID, assetID]
            .reduce(publicBaseURL) { $0.appending(path: $1) }
            .appending(queryItems: [
                .init(name: "v", value: version.uuidString.lowercased())
            ])
            .absoluteString
    }
}

private struct AdminMediaRecord: Decodable {
    let id: UUID
    let kind: String
    let scopeID: String
    let assetID: String
    let ownerUserID: String
    let contentType: String
    let byteCount: Int
    let version: UUID
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case scopeID = "scope_id"
        case assetID = "asset_id"
        case ownerUserID = "owner_user_id"
        case contentType = "content_type"
        case byteCount = "byte_count"
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
