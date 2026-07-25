import Fluent
import Foundation
import Vapor

enum GroupRepository {
    static func list(
        userID: String,
        after cursor: String?,
        limit: Int,
        on database: any Database
    ) async throws -> GroupListResponse {
        var query = GroupMemberModel.query(on: database)
            .filter(\.$userID == userID)
            .sort(\.$groupUID, .ascending)
            .with(\.$group)
            .limit(limit + 1)
        if let cursor {
            query = query.filter(\.$groupUID > cursor)
        }
        var memberships = try await query.all()
        let hasNextPage = memberships.count > limit
        if hasNextPage {
            memberships.removeLast(memberships.count - limit)
        }
        let groups = memberships.map { $0.group }
        let membersByGroup = try await membersByGroupID(
            groupIDs: groups.compactMap(\.id),
            on: database
        )
        let items = try groups.map { group in
            response(group: group, members: membersByGroup[try group.requireID()] ?? [])
        }
        return GroupListResponse(
            items: items,
            nextCursor: hasNextPage ? items.last?.uid : nil
        )
    }

    static func find(
        groupID: String,
        userID: String,
        on database: any Database
    ) async throws -> GroupResponse? {
        guard let group = try await GroupModel.query(on: database)
            .filter(\.$groupUID == groupID)
            .first() else {
            return nil
        }
        let id = try group.requireID()
        guard try await GroupMemberModel.query(on: database)
            .filter(\.$group.$id == id)
            .filter(\.$userID == userID)
            .first() != nil else {
            return nil
        }
        let members = try await memberIDs(groupID: id, on: database)
        return response(group: group, members: members)
    }

    static func upsert(
        groupID: String,
        userID: String,
        request: GroupUpsertRequest,
        on database: any Database
    ) async throws -> GroupResponse {
        try await database.transaction { transaction in
            let group: GroupModel
            if let existing = try await GroupModel.query(on: transaction)
                .filter(\.$groupUID == groupID)
                .first() {
                guard existing.createdBy == userID else {
                    throw Abort(.forbidden)
                }
                existing.name = request.name
                existing.photoURL = request.photoURL
                try await existing.update(on: transaction)
                group = existing
            } else {
                group = GroupModel(
                    groupUID: groupID,
                    name: request.name,
                    photoURL: request.photoURL,
                    createdBy: userID,
                    createdDate: .now
                )
                try await group.create(on: transaction)
            }

            let id = try group.requireID()
            try await GroupMemberModel.query(on: transaction)
                .filter(\.$group.$id == id)
                .delete()
            for memberID in request.members {
                try await GroupMemberModel(
                    groupID: id,
                    groupUID: groupID,
                    userID: memberID
                ).create(on: transaction)
            }
            return response(group: group, members: request.members)
        }
    }

    static func delete(
        groupID: String,
        userID: String,
        on database: any Database
    ) async throws {
        guard let group = try await GroupModel.query(on: database)
            .filter(\.$groupUID == groupID)
            .first() else {
            return
        }
        guard group.createdBy == userID else {
            throw Abort(.forbidden)
        }
        try await group.delete(on: database)
    }

    private static func membersByGroupID(
        groupIDs: [UUID],
        on database: any Database
    ) async throws -> [UUID: [String]] {
        guard !groupIDs.isEmpty else {
            return [:]
        }
        let memberships = try await GroupMemberModel.query(on: database)
            .filter(\.$group.$id ~~ groupIDs)
            .all()
        return Dictionary(grouping: memberships, by: { $0.$group.id })
            .mapValues { $0.map(\.userID).sorted() }
    }

    private static func memberIDs(
        groupID: UUID,
        on database: any Database
    ) async throws -> [String] {
        try await GroupMemberModel.query(on: database)
            .filter(\.$group.$id == groupID)
            .sort(\.$userID, .ascending)
            .all()
            .map(\.userID)
    }

    private static func response(group: GroupModel, members: [String]) -> GroupResponse {
        GroupResponse(
            uid: group.groupUID,
            name: group.name,
            createdDate: group.createdDate,
            photoURL: group.photoURL,
            members: members,
            createdBy: group.createdBy
        )
    }
}
