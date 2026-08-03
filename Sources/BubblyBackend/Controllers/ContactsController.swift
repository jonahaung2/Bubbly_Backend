import Fluent
import Vapor

struct ContactsController: RouteCollection {
    static func showProfilePhoto(request: Request) async throws -> Response {
        guard let userID = request.parameters.get("userID"),
              !userID.isEmpty,
              userID.count <= 128,
              let model = try await ContactModel.query(on: request.db)
                .filter(\.$firebaseUID == userID)
                .first(),
              let data = model.photoData,
              let contentType = model.photoContentType,
              let version = model.photoVersion else {
            throw Abort(.notFound)
        }
        let tag = "\"\(version.uuidString.lowercased())\""
        if request.headers.first(name: .ifNoneMatch) == tag {
            return Response(status: .notModified)
        }
        let response = Response(status: .ok, body: .init(data: data))
        response.headers.replaceOrAdd(name: .contentType, value: contentType)
        response.headers.replaceOrAdd(name: .cacheControl, value: "public, max-age=31536000, immutable")
        response.headers.replaceOrAdd(name: .eTag, value: tag)
        response.headers.replaceOrAdd(name: .xContentTypeOptions, value: "nosniff")
        return response
    }

    func boot(routes: any RoutesBuilder) throws {
        let contacts = routes.grouped("v1", "contacts")
        contacts.get(":userID", use: showContact)
        contacts.post("lookup", use: lookup)

        let profile = routes.grouped("v1", "profile")
        profile.get(use: showProfile)
        profile.put(use: updateProfile)
        profile.patch("push-token", use: updatePushToken)
        profile.put("photo", use: updatePhoto)
        profile.delete("photo", use: deletePhoto)
    }

    private func showContact(request: Request) async throws -> Response {
        guard let userID = request.parameters.get("userID"),
              !userID.isEmpty,
              userID.count <= 128 else {
            throw Abort(.badRequest)
        }
        guard let contact = try await ContactModel.query(on: request.db)
            .filter(\.$firebaseUID == userID)
            .first() else {
            return Response(status: .noContent)
        }
        return try await ContactResponse(
            model: contact,
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL
        ).encodeResponse(for: request)
    }

    private func lookup(request: Request) async throws -> [ContactResponse] {
        let body = try request.content.decode(ContactLookupRequest.self)
        let numbers = try body.validatedNumbers()
        let contacts = try await ContactModel.query(on: request.db)
            .filter(\.$mobile ~~ numbers)
            .all()
        let baseURL = request.application.bubblyConfiguration.publicBaseURL
        return contacts.map { ContactResponse(model: $0, publicBaseURL: baseURL) }
    }

    private func showProfile(request: Request) async throws -> ContactResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        guard let model = try await ContactRepository.find(userID: principal.userID, on: request.db) else {
            throw Abort(.notFound)
        }
        return response(for: model, request: request)
    }

    private func updateProfile(request: Request) async throws -> ContactResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let body = try request.content.decode(ProfileUpdateRequest.self).validated()
        let model = try await ContactRepository.upsertProfile(
            userID: principal.userID,
            profile: body,
            on: request.db
        )
        return response(for: model, request: request)
    }

    private func updatePushToken(request: Request) async throws -> HTTPStatus {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let pushToken = try request.content.decode(PushTokenUpdateRequest.self).validated()
        try await ContactRepository.upsertPushToken(
            userID: principal.userID,
            pushToken: pushToken,
            on: request.db
        )
        return .noContent
    }

    private func updatePhoto(request: Request) async throws -> ContactResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        guard let rawContentType = request.headers.first(name: .contentType),
              let contentType = rawContentType.split(separator: ";", maxSplits: 1).first
                .map({ String($0).trimmingCharacters(in: .whitespaces).lowercased() }),
              let body = request.body.data,
              body.readableBytes > 0,
              body.readableBytes <= 1_048_576 else {
            throw Abort(.payloadTooLarge)
        }
        let data = Data(body.readableBytesView)
        guard ImagePayloadValidator.isValid(data: data, contentType: contentType) else {
            throw Abort(.unsupportedMediaType)
        }
        let model = try await ContactRepository.upsertPhoto(
            userID: principal.userID,
            data: data,
            contentType: contentType,
            version: UUID(),
            on: request.db
        )
        return response(for: model, request: request)
    }

    private func deletePhoto(request: Request) async throws -> HTTPStatus {
        let principal = try request.auth.require(FirebasePrincipal.self)
        try await ContactRepository.deletePhoto(userID: principal.userID, on: request.db)
        return .noContent
    }

    private func response(for model: ContactModel, request: Request) -> ContactResponse {
        ContactResponse(
            model: model,
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL
        )
    }
}
