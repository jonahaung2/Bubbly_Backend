import SwiftUI

@main
struct BubblyAdminApp: App {
    @State private var model = AdminAppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1220, height: 820)
    }
}
