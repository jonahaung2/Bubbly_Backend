import Foundation
import Vapor

struct GroupUpsertRequest: Content, Sendable {
    let name: String
    let photoURL: String?
    let members: [String]

    func validated(currentUserID: String) throws -> GroupUpsertRequest {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let photoURL = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let members = members.filter { seen.insert($0).inserted }

        guard !name.isEmpty, name.count <= 100,
              members.count >= 2, members.count <= 256,
              members.contains(currentUserID),
              members.allSatisfy({ member in
                  !member.isEmpty
                      && member.count <= 128
                      && member.trimmingCharacters(in: .whitespacesAndNewlines) == member
              }) else {
            throw Abort(.badRequest, reason: "Group contains invalid values")
        }
        if let photoURL, !photoURL.isEmpty {
            guard photoURL.count <= 2_048,
                  let url = URL(string: photoURL),
                  url.scheme?.lowercased() == "https",
                  url.host != nil else {
                throw Abort(.badRequest, reason: "Group photoURL is invalid")
            }
        }
        return GroupUpsertRequest(
            name: name,
            photoURL: photoURL?.isEmpty == true ? nil : photoURL,
            members: members.sorted()
        )
    }
}

struct GroupResponse: Content, Sendable {
    let uid: String
    let name: String
    let createdDate: Date
    let photoURL: String?
    let members: [String]
    let createdBy: String
}

struct GroupListResponse: Content, Sendable {
    let items: [GroupResponse]
    let nextCursor: String?
}
