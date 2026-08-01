import SwiftUI

struct RootView: View {
    @Bindable var model: AdminAppModel

    var body: some View {
        NavigationSplitView {
            List(AdminSection.allCases, selection: $model.selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationTitle("Bubbly Admin")
            .safeAreaInset(edge: .bottom) {
                ConnectionStatusView(isConnected: model.isConnected)
            }
        } detail: {
            DetailContainerView(model: model)
        }
        .alert(item: $model.issue) { issue in
            Alert(title: Text(issue.title), message: Text(issue.message))
        }
        .task {
            guard !model.isConnected, !model.token.isEmpty else {
                return
            }
            await model.connect()
        }
    }
}
