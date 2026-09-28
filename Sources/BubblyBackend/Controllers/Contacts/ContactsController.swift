import Fluent
import Shared
import Vapor

struct ContactsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let contacts = routes.grouped(
            "\(API.Version.current)",
            "\(API.Path.contacts.rawValue)"
        )

        contacts.get(":\(API.Key.uid.rawValue)", use: handleGet)
        contacts.post("\(API.SubPath.lookup.rawValue)", use: handleLookUp)
        contacts.put("\(API.SubPath.put.rawValue)", use: handlePut)

        let profilePhoto = contacts.grouped("profile_photo")

        profilePhoto.put("\(API.SubPath.put.rawValue)", use: handlePutProfilePhoto)
        profilePhoto.delete("\(API.SubPath.delete.rawValue)", use: handleDeleteProfilePhoto)
    }

    private func handleGet(request: Request) async throws -> Response {
        guard let userID = request.parameters.get(API.Key.uid.rawValue),
              !userID.isEmpty,
              userID.count <= 128
        else {
            throw Abort(.badRequest)
        }
        guard let contact = try await ContactModel.query(on: request.db)
            .filter(\.$firebaseUID == userID)
            .first()
        else {
            return Response(status: .noContent)
        }

        return try await ContactDTO.ResponseModel(
            model: contact,
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL
        ).encodeResponse(for: request)
    }

    private func handleLookUp(request: Request) async throws -> Response {
        let body = try request.content.decode(ContactDTO.RequestLookUp.self)
        let numbers = body.mobileNumbers
        let contacts = try await ContactModel.query(on: request.db)
            .filter(\.$mobile ~~ numbers)
            .all()
        let baseURL = request.application.bubblyConfiguration.publicBaseURL
        return try await contacts
            .map { ContactDTO.ResponseModel(model: $0, publicBaseURL: baseURL) }
            .encodeResponse(for: request)
    }

    private func handlePut(request: Request) async throws -> Response {
        let body = try request.content.decode(ContactDTO.ResponseModel.self)
        let model = try await ContactRepository.upsertProfile(
            uid: body.uid,
            profile: body,
            on: request.db
        )
        return try await response(for: model, request: request)
            .encodeResponse(for: request)
    }

    private func handlePutProfilePhoto(request: Request) async throws -> Response {
        let principal = try request.auth.require(FirebasePrincipal.self)
        guard let rawContentType = request.headers.first(name: .contentType),
              let contentType = rawContentType.split(separator: ";", maxSplits: 1).first
              .map({ String($0).trimmingCharacters(in: .whitespaces).lowercased() }),
              let body = request.body.data,
              body.readableBytes > 0
        else {
            throw Abort(.payloadTooLarge)
        }
        let data = Data(body.readableBytesView)
        guard ImagePayloadValidator.isValid(data: data, contentType: contentType) else {
            throw Abort(.unsupportedMediaType)
        }
        let model = try await ContactRepository.upsertPhoto(
            uid: principal.userID,
            data: data,
            photoContentType: contentType,
            version: UUID(),
            on: request.db
        )
        return try await response(for: model, request: request)
            .encodeResponse(for: request)
    }

    private func handleDeleteProfilePhoto(request: Request) async throws -> HTTPStatus {
        let principal = try request.auth.require(FirebasePrincipal.self)
        try await ContactRepository.deletePhoto(userID: principal.userID, on: request.db)
        return .noContent
    }

    private func response(for model: ContactModel, request: Request) -> ContactDTO.ResponseModel {
        ContactDTO.ResponseModel(
            model: model,
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL
        )
    }

    static func showProfilePhoto(request: Request) async throws -> Response {
        guard let userID = request.parameters.get("userID"),
              !userID.isEmpty,
              userID.count <= 128,
              let model = try await ContactModel.query(on: request.db)
              .filter(\.$firebaseUID == userID)
              .first(),
              let data = model.photoData,
              let contentType = model.photoContentType,
              let version = model.photoVersion
        else {
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
}
