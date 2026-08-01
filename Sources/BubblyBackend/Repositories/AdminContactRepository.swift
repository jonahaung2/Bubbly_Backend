import Fluent
import Foundation
import Vapor

enum AdminContactRepository {
    static func list(
        page: AdminPageRequest,
        publicBaseURL: URL,
        on database: any Database
    ) async throws -> AdminPage<AdminContactResponse> {
        var query = ContactModel.query(on: database)
            .field(\.$id)
            .field(\.$firebaseUID)
            .field(\.$name)
            .field(\.$mobile)
            .field(\.$pushToken)
            .field(\.$publicKey)
            .field(\.$photoVersion)
            .field(\.$createdAt)
            .field(\.$updatedAt)
            .sort(\.$id, .ascending)
            .limit(page.limit + 1)
        if let cursor = page.cursor {
            query = query.filter(\.$id > cursor)
        }
        var models = try await query.all()
        let hasNextPage = models.count > page.limit
        if hasNextPage {
            models.removeLast(models.count - page.limit)
        }
        return AdminPage(
            items: try models.map { try response(model: $0, publicBaseURL: publicBaseURL) },
            nextCursor: hasNextPage ? models.last?.id : nil
        )
    }

    static func find(id: UUID, on database: any Database) async throws -> ContactModel {
        guard let model = try await ContactModel.find(id, on: database) else {
            throw Abort(.notFound)
        }
        return model
    }

    static func update(
        id: UUID,
        body: AdminContactUpdateRequest,
        publicBaseURL: URL,
        on database: any Database
    ) async throws -> AdminContactResponse {
        let model = try await find(id: id, on: database)
        model.name = body.name
        model.mobile = body.mobile
        model.publicKey = body.publicKey
        try await model.update(on: database)
        return try response(model: model, publicBaseURL: publicBaseURL)
    }

    static func delete(id: UUID, on database: any Database) async throws {
        let model = try await find(id: id, on: database)
        try await database.transaction { transaction in
            try await GroupMemberModel.query(on: transaction)
                .filter(\.$userID == model.firebaseUID)
                .delete()
            try await MediaAssetModel.query(on: transaction)
                .filter(\.$ownerUserID == model.firebaseUID)
                .delete()
            try await model.delete(on: transaction)
        }
    }

    static func updatePhoto(
        id: UUID,
        upload: ImageUpload,
        publicBaseURL: URL,
        on database: any Database
    ) async throws -> AdminContactResponse {
        let model = try await find(id: id, on: database)
        model.photoData = upload.data
        model.photoContentType = upload.contentType
        model.photoVersion = UUID()
        try await model.update(on: database)
        return try response(model: model, publicBaseURL: publicBaseURL)
    }

    static func deletePhoto(id: UUID, on database: any Database) async throws {
        let model = try await find(id: id, on: database)
        model.photoData = nil
        model.photoContentType = nil
        model.photoVersion = nil
        try await model.update(on: database)
    }

    private static func response(model: ContactModel, publicBaseURL: URL) throws -> AdminContactResponse {
        let photoURL = model.photoVersion.map { version in
            ["v1", "profile-photos", model.firebaseUID]
                .reduce(publicBaseURL) { $0.appending(path: $1) }
                .appending(queryItems: [
                    .init(name: "v", value: version.uuidString.lowercased())
                ])
                .absoluteString
        }
        return AdminContactResponse(
            id: try model.requireID(),
            firebaseUID: model.firebaseUID,
            name: model.name,
            mobile: model.mobile,
            publicKey: model.publicKey,
            hasPushToken: !model.pushToken.isEmpty,
            photoURL: photoURL,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }
}
