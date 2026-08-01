import Foundation

struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let nextCursor: UUID?
}

struct AdminContact: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let firebaseUID: String
    var name: String
    var mobile: String
    var publicKey: String
    let hasPushToken: Bool
    let photoURL: URL?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ContactUpdate: Encodable, Sendable {
    let name: String
    let mobile: String
    let publicKey: String
}

struct AdminGroup: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let uid: String
    var name: String
    var photoURL: String?
    let createdBy: String
    let createdDate: Date
    var members: [String]
    let createdAt: Date?
    let updatedAt: Date?
}

struct GroupUpdate: Encodable, Sendable {
    let name: String
    let photoURL: String?
    let members: [String]
}

struct AdminMedia: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: String
    let scopeID: String
    let assetID: String
    let ownerUserID: String
    let contentType: String
    let byteCount: Int
    let url: URL
    let createdAt: Date?
    let updatedAt: Date?
}

enum AdminSection: String, CaseIterable, Identifiable {
    case overview
    case contacts
    case groups
    case media
    case settings

    var id: Self { self }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .contacts: "person.2"
        case .groups: "person.3"
        case .media: "photo.on.rectangle.angled"
        case .settings: "gearshape"
        }
    }
}

struct AdminIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
