import SwiftUI

struct ContactsView: View {
    @Bindable var model: AdminAppModel
    @State private var searchText = ""
    @State private var editingContact: AdminContact?
    @State private var deletingContact: AdminContact?

    private var filteredContacts: [AdminContact] {
        guard !searchText.isEmpty else { return model.contacts }
        return model.contacts.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.mobile.localizedStandardContains(searchText)
                || $0.firebaseUID.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        Group {
            if model.contacts.isEmpty {
                ContentUnavailableView("No Contacts", systemImage: "person.2", description: Text(model.isConnected ? "No contact records were found." : "Connect to load contacts."))
            } else if filteredContacts.isEmpty {
                ContentUnavailableView.search
            } else {
                Table(filteredContacts) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Mobile", value: \.mobile)
                    TableColumn("Firebase UID", value: \.firebaseUID)
                    TableColumn("Photo") { contact in
                        Image(systemName: contact.photoURL == nil ? "person.crop.circle" : "person.crop.circle.fill")
                            .accessibilityLabel(contact.photoURL == nil ? "No profile photo" : "Has profile photo")
                    }
                    TableColumn("Actions") { contact in
                        HStack {
                            Button("Edit", systemImage: "pencil") { editingContact = contact }
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingContact = contact }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .navigationTitle("Contacts")
        .searchable(text: $searchText, prompt: "Search contacts")
        .sheet(item: $editingContact) { contact in
            ContactEditorView(contact: contact, model: model)
        }
        .confirmationDialog("Delete Contact?", isPresented: .init(get: { deletingContact != nil }, set: { if !$0 { deletingContact = nil } }), presenting: deletingContact) { contact in
            Button("Delete \(contact.name)", role: .destructive) {
                Task { await model.delete(section: .contacts, id: contact.id) }
            }
        } message: { _ in
            Text("This permanently removes the contact and profile photo.")
        }
    }
}
