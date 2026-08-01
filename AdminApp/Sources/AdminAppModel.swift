import Foundation
import Observation

@MainActor
@Observable
final class AdminAppModel {
    var selection: AdminSection? = .overview
    var baseURLText: String
    var token = ""
    var contacts: [AdminContact] = []
    var groups: [AdminGroup] = []
    var media: [AdminMedia] = []
    var isLoading = false
    var isConnected = false
    var issue: AdminIssue?
    private let client = AdminAPIClient()

    init() {
        baseURLText = UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:8080"
        do { token = try KeychainStore.loadToken() ?? "" } catch { issue = .init(title: "Keychain Error", message: error.localizedDescription) }
    }

    var baseURL: URL? { URL(string: baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)) }

    func connect() async {
        guard let baseURL else { show(error: AdminClientError.invalidServerURL); return }
        isLoading = true
        defer { isLoading = false }
        do {
            try KeychainStore.saveToken(token)
            UserDefaults.standard.set(baseURL.absoluteString, forKey: "serverURL")
            try await client.verify(baseURL: baseURL, token: token)
            isConnected = true
            await refresh()
        } catch {
            isConnected = false
            show(error: error)
        }
    }

    func refresh() async {
        guard let baseURL, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let contacts = client.contacts(baseURL: baseURL, token: token)
            async let groups = client.groups(baseURL: baseURL, token: token)
            async let media = client.media(baseURL: baseURL, token: token)
            self.contacts = try await contacts
            self.groups = try await groups
            self.media = try await media
            isConnected = true
        } catch { show(error: error) }
    }

    func save(_ contact: AdminContact) async -> Bool {
        guard let baseURL else { return false }
        do { _ = try await client.updateContact(contact, baseURL: baseURL, token: token); await refresh(); return true } catch { show(error: error); return false }
    }

    func save(_ group: AdminGroup) async -> Bool {
        guard let baseURL else { return false }
        do { _ = try await client.updateGroup(group, baseURL: baseURL, token: token); await refresh(); return true } catch { show(error: error); return false }
    }

    func delete(section: AdminSection, id: UUID) async {
        guard let baseURL else { return }
        do { try await client.delete(resource: section, id: id, baseURL: baseURL, token: token); await refresh() } catch { show(error: error) }
    }

    func replaceMedia(id: UUID, data: Data, contentType: String) async -> Bool {
        guard let baseURL else { return false }
        do { try await client.upload(data: data, contentType: contentType, path: "media/\(id)", baseURL: baseURL, token: token); await refresh(); return true } catch { show(error: error); return false }
    }

    func replacePhoto(contactID: UUID, data: Data, contentType: String) async -> Bool {
        guard let baseURL else { return false }
        do { try await client.upload(data: data, contentType: contentType, path: "contacts/\(contactID)/photo", baseURL: baseURL, token: token); await refresh(); return true } catch { show(error: error); return false }
    }

    func deletePhoto(contactID: UUID) async {
        guard let baseURL else { return }
        do { try await client.delete(path: "contacts/\(contactID)/photo", baseURL: baseURL, token: token); await refresh() } catch { show(error: error) }
    }

    func disconnect() {
        isConnected = false
        contacts = []
        groups = []
        media = []
    }

    private func show(error: any Error) { issue = .init(title: "Request Failed", message: error.localizedDescription) }
}
