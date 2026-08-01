import Foundation
import Vapor

struct AdminPage<Item: Content>: Content {
    let items: [Item]
    let nextCursor: UUID?
}

struct AdminContactResponse: Content {
    let id: UUID
    let firebaseUID: String
    let name: String
    let mobile: String
    let publicKey: String
    let hasPushToken: Bool
    let photoURL: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct AdminContactUpdateRequest: Content {
    let name: String
    let mobile: String
    let publicKey: String

    func validated() throws -> Self {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let mobile = mobile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 100,
              mobile.isEmpty || Validation.isE164(mobile),
              publicKey.count <= 8_192 else {
            throw Abort(.badRequest, reason: "Contact contains invalid values")
        }
        return .init(name: name, mobile: mobile, publicKey: publicKey)
    }
}

struct AdminGroupResponse: Content {
    let id: UUID
    let uid: String
    let name: String
    let photoURL: String?
    let createdBy: String
    let createdDate: Date
    let members: [String]
    let createdAt: Date?
    let updatedAt: Date?
}

struct AdminGroupUpdateRequest: Content {
    let name: String
    let photoURL: String?
    let members: [String]

    func validated() throws -> Self {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let photoURL = photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = Array(Set(members)).sorted()
        guard !name.isEmpty, name.count <= 100,
              !members.isEmpty, members.count <= 256,
              members.allSatisfy({ !$0.isEmpty && $0.count <= 128 && $0.trimmingCharacters(in: .whitespacesAndNewlines) == $0 }) else {
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
        return .init(name: name, photoURL: photoURL?.isEmpty == true ? nil : photoURL, members: members)
    }
}

struct AdminMediaResponse: Content {
    let id: UUID
    let kind: String
    let scopeID: String
    let assetID: String
    let ownerUserID: String
    let contentType: String
    let byteCount: Int
    let url: String
    let createdAt: Date?
    let updatedAt: Date?
}
