import SwiftUI

struct GroupsView: View {
    @Bindable var model: AdminAppModel
    @State private var searchText = ""
    @State private var editingGroup: AdminGroup?
    @State private var deletingGroup: AdminGroup?

    private var filteredGroups: [AdminGroup] {
        guard !searchText.isEmpty else { return model.groups }
        return model.groups.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.uid.localizedStandardContains(searchText)
                || $0.members.contains(where: { $0.localizedStandardContains(searchText) })
        }
    }

    var body: some View {
        Group {
            if model.groups.isEmpty {
                ContentUnavailableView("No Groups", systemImage: "person.3", description: Text(model.isConnected ? "No group records were found." : "Connect to load groups."))
            } else if filteredGroups.isEmpty {
                ContentUnavailableView.search
            } else {
                Table(filteredGroups) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Group UID", value: \.uid)
                    TableColumn("Members") { group in
                        Text(group.members.count, format: .number)
                    }
                    TableColumn("Created") { group in
                        Text(group.createdDate, format: .dateTime.year().month().day())
                    }
                    TableColumn("Actions") { group in
                        HStack {
                            Button("Edit", systemImage: "pencil") { editingGroup = group }
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingGroup = group }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .navigationTitle("Groups")
        .searchable(text: $searchText, prompt: "Search groups or members")
        .sheet(item: $editingGroup) { group in
            NavigationStack {
                GroupEditorView(group: group, model: model)
            }
        }
        .confirmationDialog("Delete Group?", isPresented: .init(get: { deletingGroup != nil }, set: { if !$0 { deletingGroup = nil } }), presenting: deletingGroup) { group in
            Button("Delete \(group.name)", role: .destructive) {
                Task { await model.delete(section: .groups, id: group.id) }
            }
        } message: { _ in
            Text("This permanently removes the group, memberships, and associated stored media.")
        }
    }
}
