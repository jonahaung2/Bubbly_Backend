import Fluent
import Vapor

enum ProfilePhotoController {
    static func show(request: Request) async throws -> Response {
        guard let userID = request.parameters.get("userID"),
              !userID.isEmpty,
              userID.count <= 128,
              let model = try await ContactModel.query(on: request.db)
                .filter(\.$firebaseUID == userID)
                .first(),
              let data = model.photoData,
              let contentType = model.photoContentType,
              let version = model.photoVersion else {
            throw Abort(.notFound)
        }
        let tag = "\"\(version.uuidString.lowercased())\""
        if request.headers.first(name: .ifNoneMatch) == tag {
            return Response(status: .notModified)
        }
        let response = Response(status: .ok, body: .init(data: data))
        response.headers.replaceOrAdd(name: .contentType, value: contentType)
        response.headers.replaceOrAdd(name: .cacheControl, value: "public, max-age=31536000, immutable")
        response.headers.replaceOrAdd(name: .eTag, value: tag)
        response.headers.replaceOrAdd(name: .xContentTypeOptions, value: "nosniff")
        return response
    }
}
