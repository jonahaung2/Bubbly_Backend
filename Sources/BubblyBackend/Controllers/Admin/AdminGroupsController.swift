import Fluent
import Vapor

struct AdminGroupsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let groups = routes.grouped("groups")
        groups.get(use: index)
        groups.put(":id", use: update)
        groups.delete(":id", use: delete)
    }

    private func index(request: Request) async throws -> AdminPage<AdminGroupResponse> {
        try await AdminGroupRepository.list(
            page: AdminPageRequest(request: request),
            on: request.db
        )
    }

    private func update(request: Request) async throws -> AdminGroupResponse {
        try await AdminGroupRepository.update(
            id: AdminParameter.id(request: request),
            body: request.content.decode(AdminGroupUpdateRequest.self).validated(),
            on: request.db
        )
    }

    private func delete(request: Request) async throws -> HTTPStatus {
        try await AdminGroupRepository.delete(
            id: AdminParameter.id(request: request),
            on: request.db
        )
        return .noContent
    }
}
