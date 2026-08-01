import Fluent
import Vapor

struct AdminMediaController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let media = routes.grouped("media")
        media.get(use: index)
        media.put(":id", use: update)
        media.delete(":id", use: delete)
    }

    private func index(request: Request) async throws -> AdminPage<AdminMediaResponse> {
        try await AdminMediaRepository.list(
            page: AdminPageRequest(request: request),
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL,
            on: request.db
        )
    }

    private func update(request: Request) async throws -> AdminMediaResponse {
        try await AdminMediaRepository.update(
            id: AdminParameter.id(request: request),
            upload: ImageUpload(request: request, maximumSize: MediaController.maximumSize),
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL,
            on: request.db
        )
    }

    private func delete(request: Request) async throws -> HTTPStatus {
        try await AdminMediaRepository.delete(
            id: AdminParameter.id(request: request),
            on: request.db
        )
        return .noContent
    }
}
