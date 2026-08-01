import SwiftUI

struct DetailContainerView: View {
    @Bindable var model: AdminAppModel

    var body: some View {
        Group {
            switch model.selection ?? .overview {
            case .overview:
                OverviewView(model: model)
            case .contacts:
                ContactsView(model: model)
            case .groups:
                GroupsView(model: model)
            case .media:
                MediaView(model: model)
            case .settings:
                SettingsView(model: model)
            }
        }
        .overlay {
            if model.isLoading {
                ProgressView("Loading")
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await model.refresh() }
                }
                .disabled(!model.isConnected || model.isLoading)
            }
        }
    }
}
