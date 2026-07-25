import Fluent
import Vapor

struct GroupsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let groups = routes.grouped("v1", "groups")
        groups.get(use: index)
        groups.get(":groupID", use: show)
        groups.put(":groupID", use: upsert)
        groups.delete(":groupID", use: delete)
    }

    private func index(request: Request) async throws -> GroupListResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let cursor = request.query[String.self, at: "after"]
        let limit = min(max(request.query[Int.self, at: "limit"] ?? 100, 1), 100)
        if let cursor {
            try validate(groupID: cursor)
        }
        return try await GroupRepository.list(
            userID: principal.userID,
            after: cursor,
            limit: limit,
            on: request.db
        )
    }

    private func show(request: Request) async throws -> GroupResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let groupID = try groupID(request: request)
        guard let group = try await GroupRepository.find(
            groupID: groupID,
            userID: principal.userID,
            on: request.db
        ) else {
            throw Abort(.notFound)
        }
        return group
    }

    private func upsert(request: Request) async throws -> GroupResponse {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let groupID = try groupID(request: request)
        let body = try request.content.decode(GroupUpsertRequest.self)
            .validated(currentUserID: principal.userID)
        return try await GroupRepository.upsert(
            groupID: groupID,
            userID: principal.userID,
            request: body,
            on: request.db
        )
    }

    private func delete(request: Request) async throws -> HTTPStatus {
        let principal = try request.auth.require(FirebasePrincipal.self)
        let groupID = try groupID(request: request)
        try await GroupRepository.delete(
            groupID: groupID,
            userID: principal.userID,
            on: request.db
        )
        return .noContent
    }

    private func groupID(request: Request) throws -> String {
        guard let groupID = request.parameters.get("groupID") else {
            throw Abort(.badRequest)
        }
        try validate(groupID: groupID)
        return groupID
    }

    private func validate(groupID: String) throws {
        guard !groupID.isEmpty,
              groupID.count <= 128,
              groupID.trimmingCharacters(in: .whitespacesAndNewlines) == groupID else {
            throw Abort(.badRequest, reason: "groupID is invalid")
        }
    }
}
