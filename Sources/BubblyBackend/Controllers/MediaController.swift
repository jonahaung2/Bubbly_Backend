import Fluent
import Foundation
import Vapor

struct MediaUploadResponse: Content, Sendable {
    let url: String
}

struct MediaController: RouteCollection {
    static let maximumSize = 10 * 1_024 * 1_024

    func boot(routes: any RoutesBuilder) throws {
        let media = routes.grouped("v1", "media")
        media.put(":kind", ":scopeID", ":assetID", use: upload)
        media.delete(":kind", ":scopeID", ":assetID", use: delete)
    }

    private func upload(request: Request) async throws -> MediaUploadResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let key = try MediaKey(request: request)
        guard let rawContentType = request.headers.first(name: .contentType),
              let contentType = rawContentType.split(separator: ";", maxSplits: 1).first
                .map({ String($0).trimmingCharacters(in: .whitespaces).lowercased() }),
              let body = request.body.data,
              body.readableBytes > 0,
              body.readableBytes <= Self.maximumSize else {
            throw Abort(.payloadTooLarge)
        }
        let data = Data(body.readableBytesView)
        guard ImagePayloadValidator.isValid(data: data, contentType: contentType) else {
            throw Abort(.unsupportedMediaType)
        }

        let asset: MediaAssetModel
        if let existing = try await key.query(on: request.db).first() {
            guard existing.ownerUserID == principal.userID else {
                throw Abort(.forbidden)
            }
            existing.data = data
            existing.contentType = contentType
            existing.version = UUID()
            try await existing.update(on: request.db)
            asset = existing
        } else {
            asset = MediaAssetModel(
                kind: key.kind,
                scopeID: key.scopeID,
                assetID: key.assetID,
                ownerUserID: principal.userID,
                data: data,
                contentType: contentType,
                version: UUID()
            )
            try await asset.create(on: request.db)
        }
        return MediaUploadResponse(url: key.publicURL(for: asset.version, request: request).absoluteString)
    }

    private func delete(request: Request) async throws -> HTTPStatus {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let key = try MediaKey(request: request)
        guard let asset = try await key.query(on: request.db).first() else {
            return .noContent
        }
        guard asset.ownerUserID == principal.userID else {
            throw Abort(.forbidden)
        }
        try await asset.delete(on: request.db)
        return .noContent
    }
}

enum PublicMediaController {
    static func show(request: Request) async throws -> Response {
        let key = try MediaKey(request: request)
        guard let asset = try await key.query(on: request.db).first() else {
            throw Abort(.notFound)
        }
        let tag = "\"\(asset.version.uuidString.lowercased())\""
        if request.headers.first(name: .ifNoneMatch) == tag {
            return Response(status: .notModified)
        }
        let response = Response(status: .ok, body: .init(data: asset.data))
        response.headers.replaceOrAdd(name: .contentType, value: asset.contentType)
        response.headers.replaceOrAdd(name: .cacheControl, value: "public, max-age=31536000, immutable")
        response.headers.replaceOrAdd(name: .eTag, value: tag)
        response.headers.replaceOrAdd(name: .xContentTypeOptions, value: "nosniff")
        return response
    }
}

private struct MediaKey {
    let kind: String
    let scopeID: String
    let assetID: String

    init(request: Request) throws {
        guard let kind = request.parameters.get("kind"),
              ["groups", "conversations"].contains(kind),
              let scopeID = request.parameters.get("scopeID"),
              Self.isValid(scopeID),
              let assetID = request.parameters.get("assetID"),
              Self.isValid(assetID) else {
            throw Abort(.badRequest, reason: "The media path is invalid")
        }
        self.kind = kind
        self.scopeID = scopeID
        self.assetID = assetID
    }

    func query(on database: any Database) -> QueryBuilder<MediaAssetModel> {
        MediaAssetModel.query(on: database)
            .filter(\.$kind == kind)
            .filter(\.$scopeID == scopeID)
            .filter(\.$assetID == assetID)
    }

    func publicURL(for version: UUID, request: Request) -> URL {
        ["v1", "media", kind, scopeID, assetID]
            .reduce(request.application.bubblyConfiguration.publicBaseURL) { $0.appending(path: $1) }
            .appending(queryItems: [.init(name: "v", value: version.uuidString.lowercased())])
    }

    private static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 128
            && value.trimmingCharacters(in: .whitespacesAndNewlines) == value
    }
}
