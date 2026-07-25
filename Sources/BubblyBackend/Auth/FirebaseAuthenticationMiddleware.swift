import Vapor

struct FirebaseAuthenticationMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let bearer = request.headers.bearerAuthorization,
              !bearer.token.isEmpty,
              bearer.token.count <= 16_384 else {
            throw Abort(.unauthorized)
        }

        do {
            let principal = try await request.application.firebaseTokenVerifier.verify(
                bearer.token,
                client: request.client
            )
            request.auth.login(principal)
            return try await next.respond(to: request)
        } catch let abort as any AbortError {
            throw abort
        } catch {
            request.logger.notice("Firebase token verification failed")
            throw Abort(.unauthorized)
        }
    }
}
