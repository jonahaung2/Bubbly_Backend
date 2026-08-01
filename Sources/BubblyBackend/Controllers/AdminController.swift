import Fluent
import Foundation
import Vapor

struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("v1", "admin")
        admin.get("contacts", use: contacts)
        admin.put("contacts", ":id", use: updateContact)
        admin.delete("contacts", ":id", use: deleteContact)
        admin.put("contacts", ":id", "photo", use: updateContactPhoto)
        admin.delete("contacts", ":id", "photo", use: deleteContactPhoto)
        admin.get("groups", use: groups)
        admin.put("groups", ":id", use: updateGroup)
        admin.delete("groups", ":id", use: deleteGroup)
        admin.get("media", use: media)
        admin.put("media", ":id", use: updateMedia)
        admin.delete("media", ":id", use: deleteMedia)
    }

    private func contacts(request: Request) async throws -> AdminPage<AdminContactResponse> {
        let page = try pageRequest(request)
        var query = ContactModel.query(on: request.db).sort(\.$id, .ascending).limit(page.limit + 1)
        if let cursor = page.cursor { query = query.filter(\.$id > cursor) }
        var models = try await query.all()
        let nextCursor = models.count > page.limit ? models.removeLast().id : nil
        return .init(items: try models.map { try contactResponse($0, request: request) }, nextCursor: nextCursor)
    }

    private func updateContact(request: Request) async throws -> AdminContactResponse {
        let model = try await contact(request)
        let body = try request.content.decode(AdminContactUpdateRequest.self).validated()
        model.name = body.name
        model.mobile = body.mobile
        model.publicKey = body.publicKey
        try await model.update(on: request.db)
        return try contactResponse(model, request: request)
    }

    private func deleteContact(request: Request) async throws -> HTTPStatus {
        let model = try await contact(request)
        try await request.db.transaction { database in
            try await GroupMemberModel.query(on: database)
                .filter(\.$userID == model.firebaseUID)
                .delete()
            try await MediaAssetModel.query(on: database)
                .filter(\.$ownerUserID == model.firebaseUID)
                .delete()
            try await model.delete(on: database)
        }
        return .noContent
    }

    private func updateContactPhoto(request: Request) async throws -> AdminContactResponse {
        let model = try await contact(request)
        let payload = try imagePayload(request: request, maximumSize: 1_048_576)
        model.photoData = payload.data
        model.photoContentType = payload.contentType
        model.photoVersion = UUID()
        try await model.update(on: request.db)
        return try contactResponse(model, request: request)
    }

    private func deleteContactPhoto(request: Request) async throws -> HTTPStatus {
        let model = try await contact(request)
        model.photoData = nil
        model.photoContentType = nil
        model.photoVersion = nil
        try await model.update(on: request.db)
        return .noContent
    }

    private func groups(request: Request) async throws -> AdminPage<AdminGroupResponse> {
        let page = try pageRequest(request)
        var query = GroupModel.query(on: request.db).sort(\.$id, .ascending).limit(page.limit + 1)
        if let cursor = page.cursor { query = query.filter(\.$id > cursor) }
        var models = try await query.all()
        let nextCursor = models.count > page.limit ? models.removeLast().id : nil
        var items: [AdminGroupResponse] = []
        items.reserveCapacity(models.count)
        for model in models {
            items.append(try await groupResponse(model, database: request.db))
        }
        return .init(items: items, nextCursor: nextCursor)
    }

    private func updateGroup(request: Request) async throws -> AdminGroupResponse {
        let group = try await group(request)
        let body = try request.content.decode(AdminGroupUpdateRequest.self).validated()
        try await request.db.transaction { database in
            group.name = body.name
            group.photoURL = body.photoURL
            try await group.update(on: database)
            let id = try group.requireID()
            try await GroupMemberModel.query(on: database).filter(\.$group.$id == id).delete()
            for userID in body.members {
                try await GroupMemberModel(groupID: id, groupUID: group.groupUID, userID: userID).create(on: database)
            }
        }
        return try await groupResponse(group, database: request.db)
    }

    private func deleteGroup(request: Request) async throws -> HTTPStatus {
        let model = try await group(request)
        try await request.db.transaction { database in
            try await MediaAssetModel.query(on: database)
                .filter(\.$kind == "groups")
                .filter(\.$scopeID == model.groupUID)
                .delete()
            try await model.delete(on: database)
        }
        return .noContent
    }

    private func media(request: Request) async throws -> AdminPage<AdminMediaResponse> {
        let page = try pageRequest(request)
        var query = MediaAssetModel.query(on: request.db).sort(\.$id, .ascending).limit(page.limit + 1)
        if let cursor = page.cursor { query = query.filter(\.$id > cursor) }
        var models = try await query.all()
        let nextCursor = models.count > page.limit ? models.removeLast().id : nil
        return .init(items: try models.map { try mediaResponse($0, request: request) }, nextCursor: nextCursor)
    }

    private func updateMedia(request: Request) async throws -> AdminMediaResponse {
        let model = try await mediaAsset(request)
        let payload = try imagePayload(request: request, maximumSize: MediaController.maximumSize)
        model.data = payload.data
        model.contentType = payload.contentType
        model.version = UUID()
        try await model.update(on: request.db)
        return try mediaResponse(model, request: request)
    }

    private func deleteMedia(request: Request) async throws -> HTTPStatus {
        try await mediaAsset(request).delete(on: request.db)
        return .noContent
    }

    private func contact(_ request: Request) async throws -> ContactModel {
        guard let id = request.parameters.get("id", as: UUID.self), let model = try await ContactModel.find(id, on: request.db) else { throw Abort(.notFound) }
        return model
    }

    private func group(_ request: Request) async throws -> GroupModel {
        guard let id = request.parameters.get("id", as: UUID.self), let model = try await GroupModel.find(id, on: request.db) else { throw Abort(.notFound) }
        return model
    }

    private func mediaAsset(_ request: Request) async throws -> MediaAssetModel {
        guard let id = request.parameters.get("id", as: UUID.self), let model = try await MediaAssetModel.find(id, on: request.db) else { throw Abort(.notFound) }
        return model
    }

    private func pageRequest(_ request: Request) throws -> (cursor: UUID?, limit: Int) {
        let cursorText = request.query[String.self, at: "after"]
        let cursor: UUID?
        if let cursorText {
            guard let value = UUID(uuidString: cursorText) else {
                throw Abort(.badRequest, reason: "Invalid cursor")
            }
            cursor = value
        } else {
            cursor = nil
        }
        return (cursor, min(max(request.query[Int.self, at: "limit"] ?? 100, 1), 200))
    }

    private func imagePayload(request: Request, maximumSize: Int) throws -> (data: Data, contentType: String) {
        guard let rawContentType = request.headers.first(name: .contentType),
              let contentType = rawContentType.split(separator: ";", maxSplits: 1).first.map({ String($0).trimmingCharacters(in: .whitespaces).lowercased() }),
              let body = request.body.data, body.readableBytes > 0, body.readableBytes <= maximumSize else { throw Abort(.payloadTooLarge) }
        let data = Data(body.readableBytesView)
        guard ImagePayloadValidator.isValid(data: data, contentType: contentType) else { throw Abort(.unsupportedMediaType) }
        return (data, contentType)
    }

    private func contactResponse(_ model: ContactModel, request: Request) throws -> AdminContactResponse {
        let photoURL = model.photoVersion.map { version in
            ["v1", "profile-photos", model.firebaseUID].reduce(request.application.bubblyConfiguration.publicBaseURL) { $0.appending(path: $1) }.appending(queryItems: [.init(name: "v", value: version.uuidString.lowercased())]).absoluteString
        }
        return .init(id: try model.requireID(), firebaseUID: model.firebaseUID, name: model.name, mobile: model.mobile, publicKey: model.publicKey, hasPushToken: !model.pushToken.isEmpty, photoURL: photoURL, createdAt: model.createdAt, updatedAt: model.updatedAt)
    }

    private func groupResponse(_ model: GroupModel, database: any Database) async throws -> AdminGroupResponse {
        let id = try model.requireID()
        let members = try await GroupMemberModel.query(on: database).filter(\.$group.$id == id).sort(\.$userID).all().map(\.userID)
        return .init(id: id, uid: model.groupUID, name: model.name, photoURL: model.photoURL, createdBy: model.createdBy, createdDate: model.createdDate, members: members, createdAt: model.createdAt, updatedAt: model.updatedAt)
    }

    private func mediaResponse(_ model: MediaAssetModel, request: Request) throws -> AdminMediaResponse {
        let url = ["v1", "media", model.kind, model.scopeID, model.assetID].reduce(request.application.bubblyConfiguration.publicBaseURL) { $0.appending(path: $1) }.appending(queryItems: [.init(name: "v", value: model.version.uuidString.lowercased())]).absoluteString
        return .init(id: try model.requireID(), kind: model.kind, scopeID: model.scopeID, assetID: model.assetID, ownerUserID: model.ownerUserID, contentType: model.contentType, byteCount: model.data.count, url: url, createdAt: model.createdAt, updatedAt: model.updatedAt)
    }
}
