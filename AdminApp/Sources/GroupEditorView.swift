import SwiftUI

struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var group: AdminGroup
    @State private var membersText: String
    @State private var photoURLText: String
    @State private var isSaving = false
    let model: AdminAppModel

    init(group: AdminGroup, model: AdminAppModel) {
        _group = State(initialValue: group)
        _membersText = State(initialValue: group.members.joined(separator: "\n"))
        _photoURLText = State(initialValue: group.photoURL ?? "")
        self.model = model
    }

    private var members: [String] {
        Array(Set(membersText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        Form {
            Section("Group") {
                LabeledContent("Group UID", value: group.uid)
                    .textSelection(.enabled)
                LabeledContent("Created By", value: group.createdBy)
                    .textSelection(.enabled)
                TextField("Name", text: $group.name)
                TextField("Photo URL", text: $photoURLText)
            }
            Section("Members") {
                TextField("One Firebase UID per line", text: $membersText, axis: .vertical)
                    .lineLimit(6 ... 16)
                LabeledContent("Member Count", value: members.count, format: .number)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Group")
        .frame(minWidth: 600, minHeight: 540)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || members.isEmpty || isSaving)
            }
        }
    }

    private func save() {
        group.members = members
        group.photoURL = photoURLText.isEmpty ? nil : photoURLText
        isSaving = true
        Task {
            if await model.save(group) { dismiss() }
            isSaving = false
        }
    }
}
