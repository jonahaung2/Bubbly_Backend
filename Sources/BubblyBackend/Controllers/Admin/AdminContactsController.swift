import Fluent
import Vapor

struct AdminContactsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let contacts = routes.grouped("contacts")
        contacts.get(use: index)
        contacts.put(":id", use: update)
        contacts.delete(":id", use: delete)
        contacts.put(":id", "photo", use: updatePhoto)
        contacts.delete(":id", "photo", use: deletePhoto)
    }

    private func index(request: Request) async throws -> AdminPage<AdminContactResponse> {
        try await AdminContactRepository.list(
            page: AdminPageRequest(request: request),
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL,
            on: request.db
        )
    }

    private func update(request: Request) async throws -> AdminContactResponse {
        try await AdminContactRepository.update(
            id: AdminParameter.id(request: request),
            body: request.content.decode(AdminContactUpdateRequest.self).validated(),
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL,
            on: request.db
        )
    }

    private func delete(request: Request) async throws -> HTTPStatus {
        try await AdminContactRepository.delete(
            id: AdminParameter.id(request: request),
            on: request.db
        )
        return .noContent
    }

    private func updatePhoto(request: Request) async throws -> AdminContactResponse {
        try await AdminContactRepository.updatePhoto(
            id: AdminParameter.id(request: request),
            upload: ImageUpload(request: request, maximumSize: 1_048_576),
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL,
            on: request.db
        )
    }

    private func deletePhoto(request: Request) async throws -> HTTPStatus {
        try await AdminContactRepository.deletePhoto(
            id: AdminParameter.id(request: request),
            on: request.db
        )
        return .noContent
    }
}
