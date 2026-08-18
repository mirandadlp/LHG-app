import Foundation

/// Every failure the app can show a person, phrased the way they would want to
/// read it rather than the way the transport reported it.
enum APIError: LocalizedError, Equatable {
    case notConnected
    case timedOut
    case unauthorized
    case forbidden(String)
    case notFound
    case validation(message: String, fields: [String: [String]])
    case rateLimited(message: String)
    case server(status: Int, message: String)
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "No connection. Check your signal and try again."
        case .timedOut:
            return "The server took too long to respond. Try again."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden(let message):
            return message.isEmpty ? "Your role does not permit this action." : message
        case .notFound:
            return "That record no longer exists."
        case .validation(let message, _):
            return message
        case .rateLimited(let message):
            return message
        case .server(let status, let message):
            return message.isEmpty ? "The server returned an error (\(status))." : message
        case .decoding(let detail):
            return "The server sent something unexpected. \(detail)"
        case .unknown(let detail):
            return detail
        }
    }

    /// Validation messages for a specific field key, for inline display.
    func messages(for field: String) -> [String] {
        guard case .validation(_, let fields) = self else { return [] }
        return fields["values.\(field)"] ?? fields[field] ?? []
    }

    /// Only an expired session should bounce the user back to sign-in.
    var requiresReauthentication: Bool { self == .unauthorized }
}
