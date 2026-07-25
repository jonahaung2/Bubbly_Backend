import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async -> HTTPStatus in
        .ok
    }

    app.get("v1", "profile-photos", ":userID", use: ProfilePhotoController.show)
    app.get("v1", "media", ":kind", ":scopeID", ":assetID", use: PublicMediaController.show)

    let authenticated = app.grouped(FirebaseAuthenticationMiddleware())
    try authenticated.register(collection: ContactsController())
    try authenticated.register(collection: ProfileController())
    try authenticated.register(collection: GroupsController())
    try authenticated.register(collection: PushNotificationsController())
    try authenticated.register(collection: MediaController())
}
