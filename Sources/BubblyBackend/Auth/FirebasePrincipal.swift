import Vapor

struct FirebasePrincipal: Authenticatable, Sendable {
    let userID: String
}
