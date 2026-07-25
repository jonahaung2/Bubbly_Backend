import Fluent
import Vapor

struct ContactsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let contacts = routes.grouped("v1", "contacts")
        contacts.get(":userID", use: show)
        contacts.post("lookup", use: lookup)
    }

    private func show(request: Request) async throws -> Response {
        guard let userID = request.parameters.get("userID"),
              !userID.isEmpty,
              userID.count <= 128 else {
            throw Abort(.badRequest)
        }
        guard let contact = try await ContactModel.query(on: request.db)
            .filter(\.$firebaseUID == userID)
            .first() else {
            return Response(status: .noContent)
        }
        return try await ContactResponse(
            model: contact,
            publicBaseURL: request.application.bubblyConfiguration.publicBaseURL
        ).encodeResponse(for: request)
    }

    private func lookup(request: Request) async throws -> [ContactResponse] {
        let body = try request.content.decode(ContactLookupRequest.self)
        let numbers = try body.validatedNumbers()
        let contacts = try await ContactModel.query(on: request.db)
            .filter(\.$mobile ~~ numbers)
            .all()
        let baseURL = request.application.bubblyConfiguration.publicBaseURL
        return contacts.map { ContactResponse(model: $0, publicBaseURL: baseURL) }
    }
}
