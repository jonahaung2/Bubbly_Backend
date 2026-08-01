import Vapor

struct AdminController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("v1", "admin")
        try admin.register(collection: AdminContactsController())
        try admin.register(collection: AdminGroupsController())
        try admin.register(collection: AdminMediaController())
    }
}
