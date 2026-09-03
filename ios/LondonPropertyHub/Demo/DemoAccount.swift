import Foundation

/// The demo sign-ins.
///
/// Signing in with one of these addresses never reaches the server. `PropertyAPI`
/// routes every call to `DemoBackend` instead — an in-memory copy of the
/// portfolio that enforces the same rules the API does: the same role scoping,
/// the same lock on a submitted record, the same audit trail, the same
/// large-change flags. Every screen can be exercised with no backend running.
enum DemoPersona: String, CaseIterable, Identifiable, Sendable {
    case admin
    case manager
    case leadership

    var id: String { rawValue }

    /// The address typed on the sign-in screen. Deliberately obvious: nobody
    /// should be able to reach demo data by mistyping a real address.
    var email: String {
        switch self {
        case .admin: return "demo@londonhotelgroup.co.uk"
        case .manager: return "demo.manager@londonhotelgroup.co.uk"
        case .leadership: return "demo.leadership@londonhotelgroup.co.uk"
        }
    }

    var name: String {
        switch self {
        case .admin: return "Priya Raman"
        case .manager: return "Jane Smith"
        case .leadership: return "Meher N."
        }
    }

    var role: UserRole {
        switch self {
        case .admin: return .admin
        case .manager: return .manager
        case .leadership: return .leadership
        }
    }

    var phone: String? {
        switch self {
        case .admin: return "020 7946 0100"
        case .manager: return "020 7946 0112"
        case .leadership: return nil
        }
    }

    /// Shown on the sign-in card so a tester picks the role that shows the
    /// behaviour they are looking for rather than guessing.
    var blurb: String {
        switch self {
        case .admin: return "Everything: approvals, import, custom fields."
        case .manager: return "Three properties, editable until submitted."
        case .leadership: return "The whole portfolio, read-only."
        }
    }

    var icon: String {
        switch self {
        case .admin: return "person.badge.key.fill"
        case .manager: return "hammer.fill"
        case .leadership: return "eye.fill"
        }
    }

    var currentUser: CurrentUser {
        CurrentUser(
            id: DemoAccount.userID(for: self),
            name: name,
            email: email,
            role: role,
            roleLabel: role.label,
            phone: phone,
            jobTitle: role.label,
            initials: name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }.joined(),
            permissions: CurrentUser.Permissions(
                canCreateProperties: role == .admin,
                canReview: role == .admin,
                canImport: role == .admin,
                canManageFields: role == .admin,
                canEdit: role != .leadership
            )
        )
    }
}

/// How the app recognises a demo sign-in, and how a relaunch recognises the one
/// it left running.
enum DemoAccount {

    /// Demo sign-ins are available in every build, Release included: an App
    /// Store reviewer needs a way in, and so does anyone showing the app
    /// somewhere the API is not reachable. To keep them out of production
    /// builds instead, change this to `!APIConfiguration.isProduction` — the
    /// sign-in card disappears, the addresses stop being recognised, and any
    /// demo session stored on the device is ignored.
    static let isEnabled = true

    /// The password shown on the sign-in card. Any password is accepted for a
    /// demo address — the point is to get in, not to guard anything.
    static let password = "demo"

    /// Written to the Keychain like a real token so `SessionStore.restore()`
    /// takes its usual path. The prefix is what marks the stored session as a
    /// demo one when the app comes back up.
    static let tokenPrefix = "demo-session:"

    static func persona(forEmail email: String) -> DemoPersona? {
        guard isEnabled else { return nil }

        let normalised = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return DemoPersona.allCases.first { $0.email == normalised }
    }

    static func token(for persona: DemoPersona) -> String {
        tokenPrefix + persona.rawValue
    }

    static func persona(forToken token: String?) -> DemoPersona? {
        guard isEnabled, let token, token.hasPrefix(tokenPrefix) else { return nil }

        return DemoPersona(rawValue: String(token.dropFirst(tokenPrefix.count)))
    }

    /// Distinct ids so the audit trail can tell the three personas apart.
    static func userID(for persona: DemoPersona) -> Int {
        switch persona {
        case .admin: return 901
        case .manager: return 902
        case .leadership: return 903
        }
    }
}
