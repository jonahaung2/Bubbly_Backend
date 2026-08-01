import SwiftUI
import UniformTypeIdentifiers

struct ContactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contact: AdminContact
    @State private var isImporting = false
    @State private var isSaving = false
    let model: AdminAppModel

    init(contact: AdminContact, model: AdminAppModel) {
        _contact = State(initialValue: contact)
        self.model = model
    }

    var body: some View {
        Form {
            Section("Identity") {
                LabeledContent("Firebase UID", value: contact.firebaseUID)
                    .textSelection(.enabled)
                TextField("Name", text: $contact.name)
                TextField("Mobile", text: $contact.mobile)
                TextField("Public Key", text: $contact.publicKey, axis: .vertical)
                    .lineLimit(3 ... 8)
            }
            Section("Profile Photo") {
                if let photoURL = contact.photoURL {
                    AsyncImage(url: photoURL) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                        .frame(maxHeight: 220)
                        .accessibilityLabel("Profile photo for \(contact.name)")
                }
                HStack {
                    Button("Replace Photo", systemImage: "photo.badge.arrow.down") { isImporting = true }
                    if contact.photoURL != nil {
                        Button("Remove Photo", systemImage: "trash", role: .destructive) {
                            Task { await model.deletePhoto(contactID: contact.id); dismiss() }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Contact")
        .frame(minWidth: 560, minHeight: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.png, .jpeg, .heic]) { result in
            importPhoto(result)
        }
    }

    private func save() {
        isSaving = true
        Task {
            if await model.save(contact) { dismiss() }
            isSaving = false
        }
    }

    private func importPhoto(_ result: Result<URL, any Error>) {
        Task {
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.preferredMIMEType ?? "application/octet-stream"
                if await model.replacePhoto(contactID: contact.id, data: data, contentType: contentType) { dismiss() }
            } catch {
                model.issue = .init(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }
}
