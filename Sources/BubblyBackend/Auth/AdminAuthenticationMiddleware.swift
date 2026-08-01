import Vapor

struct AdminAuthenticationMiddleware: AsyncMiddleware {
    let expectedToken: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token,
              Array(token.utf8).secureCompare(to: Array(expectedToken.utf8)) else {
            throw Abort(.unauthorized)
        }
        return try await next.respond(to: request)
    }
}
