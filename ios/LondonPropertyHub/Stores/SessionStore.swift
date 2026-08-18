import Foundation
import Observation

/// Who is signed in, and everything the app needs before it can render: the
/// field registry, the controlled lists and the accommodation model.
@MainActor
@Observable
final class SessionStore {

    enum State: Equatable {
        case launching
        case signedOut
        case signedIn
    }

    private(set) var state: State = .launching
    private(set) var user: CurrentUser?
    private(set) var bootstrap: BootstrapPayload?

    var signInError: String?
    var isSigningIn = false

    /// The banner shown when a save fails or a background refresh breaks.
    var toast: Toast?

    private let api: PropertyAPI
    private var expiryObserver: NSObjectProtocol?

    init(api: PropertyAPI = PropertyAPI()) {
        self.api = api
        observeSessionExpiry()
    }

    deinit {
        if let expiryObserver {
            NotificationCenter.default.removeObserver(expiryObserver)
        }
    }

    // MARK: - Lifecycle

    /// Called once at launch: if a token is already in the Keychain, use it
    /// rather than asking the user to sign in again.
    func restore() async {
        guard await APIClient.shared.isAuthenticated else {
            state = .signedOut
            return
        }

        do {
            let payload = try await api.bootstrap()
            bootstrap = payload
            user = payload.user
            state = .signedIn
        } catch {
            // A stale or revoked token just means signing in again.
            await APIClient.shared.clearToken()
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        guard !isSigningIn else { return }

        isSigningIn = true
        signInError = nil

        defer { isSigningIn = false }

        do {
            let response = try await api.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            user = response.user
            bootstrap = try await api.bootstrap()
            state = .signedIn
        } catch let error as APIError {
            signInError = error.errorDescription
        } catch {
            signInError = error.localizedDescription
        }
    }

    func signOut() async {
        await api.logout()

        user = nil
        bootstrap = nil
        state = .signedOut
    }

    /// Pull the registry again after corporate adds or removes a custom field.
    func refreshRegistry() async {
        guard state == .signedIn else { return }

        if let payload = try? await api.bootstrap() {
            bootstrap = payload
            user = payload.user
        }
    }

    // MARK: - Registry access

    var fields: [FieldDefinition] { bootstrap?.fields ?? [] }

    func fields(in section: FieldSection) -> [FieldDefinition] {
        fields.filter { $0.section == section }
    }

    func field(_ key: String) -> FieldDefinition? {
        fields.first { $0.key == key }
    }

    var accommodationTypes: [AccommodationType] { bootstrap?.accommodationTypes ?? [] }

    var accommodationGroups: [String] { bootstrap?.accommodationGroups ?? [] }

    func accommodationTypes(in group: String) -> [AccommodationType] {
        accommodationTypes.filter { $0.group == group }
    }

    func options(_ listKey: String?) -> [String] {
        guard let listKey else { return [] }
        return bootstrap?.options[listKey] ?? []
    }

    var optionLists: [String] { (bootstrap?.options.keys).map { $0.sorted() } ?? [] }

    var measurementUnits: [String] { bootstrap?.measurementUnits ?? ["m²", "ft²", "m", "ft"] }

    var reportColumns: [String] { bootstrap?.reportColumns ?? [] }

    var defaultReportColumns: [String] { bootstrap?.defaultReportColumns ?? [] }

    /// Keys grouped the way the accommodation tab lays them out.
    func accommodationKeys(in group: String) -> [String] {
        accommodationTypes(in: group).map(\.key)
    }

    // MARK: - Permissions

    var isAdmin: Bool { user?.role == .admin }
    var isManager: Bool { user?.role == .manager }
    var isLeadership: Bool { user?.role == .leadership }
    var canReview: Bool { user?.permissions.canReview ?? false }
    var canImport: Bool { user?.permissions.canImport ?? false }
    var canManageFields: Bool { user?.permissions.canManageFields ?? false }
    var canCreateProperties: Bool { user?.permissions.canCreateProperties ?? false }

    // MARK: - Toasts

    func show(_ message: String, style: Toast.Style = .info) {
        toast = Toast(message: message, style: style)
    }

    func show(error: Error) {
        let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
        toast = Toast(message: message, style: .error)
    }

    // MARK: - Private

    private func observeSessionExpiry() {
        expiryObserver = NotificationCenter.default.addObserver(
            forName: APIClient.sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .signedIn else { return }

                self.user = nil
                self.bootstrap = nil
                self.state = .signedOut
                self.signInError = "Your session expired. Please sign in again."
            }
        }
    }
}

// MARK: - Toast

struct Toast: Equatable, Identifiable {
    enum Style {
        case info, success, error
    }

    let id = UUID()
    let message: String
    var style: Style = .info
}
