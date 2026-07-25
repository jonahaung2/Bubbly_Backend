import Fluent
import Vapor

struct ProfileController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let profile = routes.grouped("v1", "profile")
        profile.get(use: show)
        profile.put(use: update)
        profile.patch("push-token", use: updatePushToken)
        profile.put("photo", use: updatePhoto)
        profile.delete("photo", use: deletePhoto)
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

    private func show(request: Request) async throws -> ContactResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        guard let model = try await ContactRepository.find(userID: principal.userID, on: request.db) else {
            throw Abort(.notFound)
        }
        return response(for: model, request: request)
    }

    private func update(request: Request) async throws -> ContactResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let body = try request.content.decode(ProfileUpdateRequest.self).validated()
        let model = try await ContactRepository.upsertProfile(
            userID: principal.userID,
            profile: body,
            on: request.db
        )
        return response(for: model, request: request)
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
