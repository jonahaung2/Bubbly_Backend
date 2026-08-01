import Foundation

actor AdminAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func contacts(baseURL: URL, token: String) async throws -> [AdminContact] {
        try await allPages(path: "contacts", baseURL: baseURL, token: token)
    }

    func groups(baseURL: URL, token: String) async throws -> [AdminGroup] {
        try await allPages(path: "groups", baseURL: baseURL, token: token)
    }

    func media(baseURL: URL, token: String) async throws -> [AdminMedia] {
        try await allPages(path: "media", baseURL: baseURL, token: token)
    }

    func updateContact(_ contact: AdminContact, baseURL: URL, token: String) async throws -> AdminContact {
        try await send(method: "PUT", path: "contacts/\(contact.id)", body: ContactUpdate(name: contact.name, mobile: contact.mobile, publicKey: contact.publicKey), baseURL: baseURL, token: token)
    }

    func updateGroup(_ group: AdminGroup, baseURL: URL, token: String) async throws -> AdminGroup {
        try await send(method: "PUT", path: "groups/\(group.id)", body: GroupUpdate(name: group.name, photoURL: group.photoURL, members: group.members), baseURL: baseURL, token: token)
    }

    func delete(resource: AdminSection, id: UUID, baseURL: URL, token: String) async throws {
        let request = try request(method: "DELETE", path: "\(resource.rawValue)/\(id)", baseURL: baseURL, token: token)
        _ = try await data(for: request)
    }

    func upload(data: Data, contentType: String, path: String, baseURL: URL, token: String) async throws {
        var request = try request(method: "PUT", path: path, baseURL: baseURL, token: token)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try await self.data(for: request)
    }

    func delete(path: String, baseURL: URL, token: String) async throws {
        let request = try request(method: "DELETE", path: path, baseURL: baseURL, token: token)
        _ = try await data(for: request)
    }

    func verify(baseURL: URL, token: String) async throws {
        let _: Page<AdminContact> = try await page(path: "contacts", cursor: nil, baseURL: baseURL, token: token)
    }

    private func allPages<Item: Decodable & Sendable>(path: String, baseURL: URL, token: String) async throws -> [Item] {
        var result: [Item] = []
        var cursor: UUID?
        repeat {
            try Task.checkCancellation()
            let next: Page<Item> = try await page(path: path, cursor: cursor, baseURL: baseURL, token: token)
            result.append(contentsOf: next.items)
            cursor = next.nextCursor
        } while cursor != nil
        return result
    }

    private func page<Item: Decodable & Sendable>(path: String, cursor: UUID?, baseURL: URL, token: String) async throws -> Page<Item> {
        var components = URLComponents(url: try endpoint(path: path, baseURL: baseURL), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "200")] + (cursor.map { [URLQueryItem(name: "after", value: $0.uuidString)] } ?? [])
        guard let url = components?.url else { throw AdminClientError.invalidServerURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let responseData = try await data(for: request)
        return try decoder.decode(Page<Item>.self, from: responseData)
    }

    private func send<Body: Encodable, Output: Decodable>(method: String, path: String, body: Body, baseURL: URL, token: String) async throws -> Output {
        var request = try request(method: method, path: path, baseURL: baseURL, token: token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try decoder.decode(Output.self, from: await data(for: request))
    }

    private func request(method: String, path: String, baseURL: URL, token: String) throws -> URLRequest {
        var request = URLRequest(url: try endpoint(path: path, baseURL: baseURL))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func endpoint(path: String, baseURL: URL) throws -> URL {
        guard let scheme = baseURL.scheme?.lowercased(), ["http", "https"].contains(scheme), baseURL.host != nil else { throw AdminClientError.invalidServerURL }
        return ["v1", "admin"].reduce(baseURL) { $0.appending(path: $1) }.appending(path: path)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AdminClientError.invalidResponse }
        guard (200 ... 299).contains(response.statusCode) else {
            if response.statusCode == 401 { throw AdminClientError.unauthorized }
            let reason = (try? decoder.decode(ServerError.self, from: data).reason) ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw AdminClientError.server(status: response.statusCode, reason: reason)
        }
        return data
    }
}

private struct ServerError: Decodable { let reason: String }

enum AdminClientError: LocalizedError {
    case invalidServerURL
    case invalidResponse
    case unauthorized
    case server(status: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL: "Enter a valid HTTP or HTTPS server URL."
        case .invalidResponse: "The server returned an invalid response."
        case .unauthorized: "The admin token was rejected."
        case let .server(status, reason): "Server error \(status): \(reason)"
        }
    }
}
