import Foundation
import Vapor

struct AdminPageRequest: Sendable {
    static let defaultLimit = 100
    static let maximumLimit = 200

    let cursor: UUID?
    let limit: Int

    init(request: Request) throws {
        try self.init(
            cursorValue: request.query[String.self, at: "after"],
            requestedLimit: request.query[Int.self, at: "limit"]
        )
    }

    init(cursorValue: String?, requestedLimit: Int?) throws {
        if let value = cursorValue {
            guard let cursor = UUID(uuidString: value) else {
                throw Abort(.badRequest, reason: "Invalid cursor")
            }
            self.cursor = cursor
        } else {
            cursor = nil
        }
        limit = min(
            max(requestedLimit ?? Self.defaultLimit, 1),
            Self.maximumLimit
        )
    }
}

struct ImageUpload: Sendable {
    let data: Data
    let contentType: String

    init(request: Request, maximumSize: Int) throws {
        guard let rawContentType = request.headers.first(name: .contentType),
              let contentType = rawContentType
                .split(separator: ";", maxSplits: 1)
                .first
                .map({ String($0).trimmingCharacters(in: .whitespaces).lowercased() }),
              let body = request.body.data,
              body.readableBytes > 0,
              body.readableBytes <= maximumSize else {
            throw Abort(.payloadTooLarge)
        }
        let data = Data(body.readableBytesView)
        guard ImagePayloadValidator.isValid(data: data, contentType: contentType) else {
            throw Abort(.unsupportedMediaType)
        }
        self.data = data
        self.contentType = contentType
    }
}

enum AdminParameter {
    static func id(request: Request) throws -> UUID {
        guard let id = request.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid resource identifier")
        }
        return id
    }
}
