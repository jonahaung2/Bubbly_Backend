import Fluent
import Foundation
import Vapor

enum AdminGroupRepository {
    static func list(
        page: AdminPageRequest,
        on database: any Database
    ) async throws -> AdminPage<AdminGroupResponse> {
        var query = GroupModel.query(on: database)
            .sort(\.$id, .ascending)
            .limit(page.limit + 1)
        if let cursor = page.cursor {
            query = query.filter(\.$id > cursor)
        }
        var groups = try await query.all()
        let hasNextPage = groups.count > page.limit
        if hasNextPage {
            groups.removeLast(groups.count - page.limit)
        }
        let membersByGroup = try await membersByGroupID(
            groupIDs: groups.compactMap(\.id),
            on: database
        )
        return AdminPage(
            items: try groups.map { group in
                let id = try group.requireID()
                return try response(group: group, members: membersByGroup[id] ?? [])
            },
            nextCursor: hasNextPage ? groups.last?.id : nil
        )
    }

    static func update(
        id: UUID,
        body: AdminGroupUpdateRequest,
        on database: any Database
    ) async throws -> AdminGroupResponse {
        let group = try await find(id: id, on: database)
        try await database.transaction { transaction in
            group.name = body.name
            group.photoURL = body.photoURL
            try await group.update(on: transaction)
            try await replaceMembers(group: group, userIDs: body.members, on: transaction)
        }
        return try response(group: group, members: body.members)
    }

    static func delete(id: UUID, on database: any Database) async throws {
        let group = try await find(id: id, on: database)
        try await database.transaction { transaction in
            try await MediaAssetModel.query(on: transaction)
                .filter(\.$kind == "groups")
                .filter(\.$scopeID == group.groupUID)
                .delete()
            try await group.delete(on: transaction)
        }
    }

    private static func find(id: UUID, on database: any Database) async throws -> GroupModel {
        guard let group = try await GroupModel.find(id, on: database) else {
            throw Abort(.notFound)
        }
        return group
    }

    private static func replaceMembers(
        group: GroupModel,
        userIDs: [String],
        on database: any Database
    ) async throws {
        let id = try group.requireID()
        try await GroupMemberModel.query(on: database)
            .filter(\.$group.$id == id)
            .delete()
        let memberships = userIDs.map { userID in
            GroupMemberModel(
                groupID: id,
                groupUID: group.groupUID,
                userID: userID
            )
        }
        try await memberships.create(on: database)
    }

    private static func membersByGroupID(
        groupIDs: [UUID],
        on database: any Database
    ) async throws -> [UUID: [String]] {
        guard !groupIDs.isEmpty else {
            return [:]
        }
        let memberships = try await GroupMemberModel.query(on: database)
            .field(\.$group.$id)
            .field(\.$userID)
            .filter(\.$group.$id ~~ groupIDs)
            .sort(\.$userID, .ascending)
            .all()
        return Dictionary(grouping: memberships, by: { $0.$group.id })
            .mapValues { $0.map(\.userID) }
    }

    private static func response(group: GroupModel, members: [String]) throws -> AdminGroupResponse {
        AdminGroupResponse(
            id: try group.requireID(),
            uid: group.groupUID,
            name: group.name,
            photoURL: group.photoURL,
            createdBy: group.createdBy,
            createdDate: group.createdDate,
            members: members,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt
        )
    }
}
