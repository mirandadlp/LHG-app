import Foundation

/// The single path to the server.
///
/// Every request goes through `send`, so authentication, error translation and
/// the expired-session signal are handled in one place rather than repeated at
/// each call site.
actor APIClient {

    static let shared = APIClient()

    private let session: URLSession
    private let tokenStore = TokenStore()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Raised when the server rejects the token, so the app can sign the user
    /// out from wherever they happen to be.
    static let sessionExpired = Notification.Name("APIClientSessionExpired")

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 120
            configuration.waitsForConnectivity = false
            configuration.httpAdditionalHeaders = ["Accept": "application/json"]
            self.session = URLSession(configuration: configuration)
        }
    }

    // MARK: - Token

    var token: String? { tokenStore.read() }
    var isAuthenticated: Bool { tokenStore.read() != nil }

    func store(token: String) { tokenStore.save(token) }
    func clearToken() { tokenStore.delete() }

    // MARK: - Verbs

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        try await send(path: path, method: "GET", query: query, as: type)
    }

    func post<T: Decodable>(_ path: String, body: Encodable? = nil, as type: T.Type) async throws -> T {
        try await send(path: path, method: "POST", body: body, as: type)
    }

    func patch<T: Decodable>(_ path: String, body: Encodable? = nil, as type: T.Type) async throws -> T {
        try await send(path: path, method: "PATCH", body: body, as: type)
    }

    func delete<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await send(path: path, method: "DELETE", as: type)
    }

    /// Fire-and-forget for endpoints whose body the app does not need.
    @discardableResult
    func post(_ path: String, body: Encodable? = nil) async throws -> Data {
        try await raw(path: path, method: "POST", body: body).0
    }

    // MARK: - Downloads

    /// Fetch a file (an export, the sample spreadsheet) and write it to a
    /// temporary URL the share sheet can hand to another app.
    func download(_ path: String, query: [URLQueryItem] = [], suggestedName: String) async throws -> URL {
        let (data, response) = try await raw(path: path, method: "GET", query: query)

        // The server names the file; fall back to the caller's suggestion.
        let filename = (response.value(forHTTPHeaderField: "X-Filename")).flatMap {
            $0.isEmpty ? nil : $0
        } ?? suggestedName

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: destination)
        try data.write(to: destination, options: .atomic)

        return destination
    }

    // MARK: - Uploads

    /// Multipart upload for documents and spreadsheet imports.
    func upload<T: Decodable>(
        _ path: String,
        fileURL: URL,
        fileField: String = "file",
        fields: [String: String] = [:],
        as type: T.Type
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeRequest(path: path, method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Security-scoped access is required for files chosen in the Files app.
        let needsScope = fileURL.startAccessingSecurityScopedResource()
        defer { if needsScope { fileURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        for (name, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await perform(request)
        try validate(response: response, data: data)

        return try decode(type, from: data)
    }

    // MARK: - Core

    private func send<T: Decodable>(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        as type: T.Type
    ) async throws -> T {
        let (data, _) = try await raw(path: path, method: method, query: query, body: body)

        // Endpoints that answer with `{"message": "..."}` and nothing else.
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        return try decode(type, from: data)
    }

    private func raw(
        path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var request = try makeRequest(path: path, method: method, query: query)

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await perform(request)
        try validate(response: response, data: data)

        return (data, response)
    }

    private func makeRequest(path: String, method: String, query: [URLQueryItem] = []) throws -> URLRequest {
        let base = APIConfiguration.apiURL.appendingPathComponent(path)

        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw APIError.unknown("Could not build a request for \(path).")
        }

        if !query.isEmpty {
            components.queryItems = query
        }

        guard let url = components.url else {
            throw APIError.unknown("Could not build a request for \(path).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = tokenStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown("The server sent a response the app could not read.")
            }

            return (data, http)
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
                throw APIError.notConnected
            case .timedOut:
                throw APIError.timedOut
            default:
                throw APIError.unknown(error.localizedDescription)
            }
        }
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard !(200..<300).contains(response.statusCode) else { return }

        let payload = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        let message = payload?.message ?? ""

        switch response.statusCode {
        case 401:
            tokenStore.delete()
            NotificationCenter.default.post(name: Self.sessionExpired, object: nil)
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden(message)
        case 404:
            throw APIError.notFound
        case 422:
            throw APIError.validation(
                message: message.isEmpty ? "Some details need correcting." : message,
                fields: payload?.errors ?? [:]
            )
        case 429:
            throw APIError.rateLimited(
                message: message.isEmpty ? "Too many attempts. Wait a moment and try again." : message
            )
        default:
            throw APIError.server(status: response.statusCode, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw APIError.decoding("Missing '\(key.stringValue)'.")
        } catch let DecodingError.typeMismatch(_, context) {
            throw APIError.decoding("Unexpected type at \(context.codingPath.map(\.stringValue).joined(separator: ".")).")
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

// MARK: - Envelopes

struct EmptyResponse: Decodable {}

struct MessageResponse: Decodable {
    let message: String
}

private struct ErrorEnvelope: Decodable {
    let message: String?
    let errors: [String: [String]]?
}

/// Lets `Encodable` values be passed around without generics leaking into every
/// method signature.
private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        encodeValue = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
