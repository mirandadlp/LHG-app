import Foundation

// MARK: - Roles and statuses

enum UserRole: String, Codable, CaseIterable, Sendable {
    case admin
    case manager
    case leadership

    var label: String {
        switch self {
        case .admin: return "Corporate Administrator"
        case .manager: return "Property Manager"
        case .leadership: return "Leadership"
        }
    }
}

enum VerificationStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case submitted = "Submitted"
    case changesRequested = "Changes Requested"
    case verified = "Verified"
    case overdue = "Overdue"
    case needsReview = "Needs Review"

    /// Unknown statuses decode to `.notStarted` rather than failing the whole
    /// response — a server that adds a status must not break an older build.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VerificationStatus(rawValue: raw) ?? .notStarted
    }
}

/// Yes / No / N/A, the tri-state used across accessibility and lift records.
enum TriState: String, Codable, CaseIterable, Hashable, Sendable {
    case yes = "Yes"
    case no = "No"
    case notApplicable = "N/A"
}

// MARK: - User

struct CurrentUser: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let email: String
    let role: UserRole
    let roleLabel: String
    let phone: String?
    let jobTitle: String?
    let initials: String
    let permissions: Permissions

    struct Permissions: Codable, Equatable, Sendable {
        let canCreateProperties: Bool
        let canReview: Bool
        let canImport: Bool
        let canManageFields: Bool
        let canEdit: Bool
    }
}

// MARK: - Field registry

enum FieldType: String, Codable, Sendable {
    case text, email, postcode, number, decimal, date, yesno
    case select
    case customSelect = "custom-select"
    case measurement, notes

    /// Anything the server adds later is rendered as plain text rather than
    /// dropped, so an older build still shows the value.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FieldType(rawValue: raw) ?? .text
    }
}

enum FieldSection: String, Codable, CaseIterable, Hashable, Sendable {
    case general, dimensions, accessibility, building

    var label: String {
        switch self {
        case .general: return "General information"
        case .dimensions: return "Room dimensions"
        case .accessibility: return "Accessibility"
        case .building: return "Building"
        }
    }

    var shortLabel: String {
        switch self {
        case .general: return "General"
        case .dimensions: return "Dimensions"
        case .accessibility: return "Accessibility"
        case .building: return "Building"
        }
    }
}

struct FieldDefinition: Codable, Identifiable, Hashable, Sendable {
    /// The database row behind a custom field. Base fields are part of the
    /// record's contract and have no row — they cannot be deleted.
    let definitionId: Int?
    let key: String
    let section: FieldSection
    let label: String
    let type: FieldType
    let required: Bool
    let help: String?
    let unit: String?
    let optionListKey: String?
    let optionList: [String]?
    let custom: Bool

    var id: String { key }
}

struct AccommodationType: Codable, Identifiable, Hashable, Sendable {
    let key: String
    let label: String
    let group: String

    var id: String { key }
}

// MARK: - Field values

/// A single field value. The API sends heterogeneous JSON per field type, so
/// this box carries whichever shape arrived and hands back typed accessors.
enum FieldValue: Codable, Hashable, Sendable {
    case text(String)
    case number(Double)
    case measurement(value: Double?, unit: String)
    case empty

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .empty
            return
        }

        if let string = try? container.decode(String.self) {
            self = string.isEmpty ? .empty : .text(string)
            return
        }

        if let number = try? container.decode(Double.self) {
            self = .number(number)
            return
        }

        if let boxed = try? container.decode(MeasurementBox.self) {
            self = .measurement(value: boxed.v, unit: boxed.u ?? "m²")
            return
        }

        self = .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .text(let string):
            try container.encode(string)
        case .number(let number):
            // Whole numbers encode as integers so the API stores 7, not 7.0.
            if number == number.rounded(), abs(number) < 1e15 {
                try container.encode(Int(number))
            } else {
                try container.encode(number)
            }
        case .measurement(let value, let unit):
            try container.encode(MeasurementBox(v: value, u: unit))
        case .empty:
            try container.encodeNil()
        }
    }

    private struct MeasurementBox: Codable {
        let v: Double?
        let u: String?
    }

    // MARK: Accessors

    var isEmpty: Bool {
        switch self {
        case .empty: return true
        case .text(let string): return string.isEmpty
        case .measurement(let value, _): return value == nil
        case .number: return false
        }
    }

    var stringValue: String {
        switch self {
        case .text(let string): return string
        case .number(let number): return Self.trim(number)
        case .measurement(let value, let unit):
            guard let value else { return "" }
            return "\(Self.trim(value)) \(unit)"
        case .empty: return ""
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let number): return number
        case .text(let string): return Double(string)
        case .measurement(let value, _): return value
        case .empty: return nil
        }
    }

    var intValue: Int? { doubleValue.map { Int($0) } }

    var triState: TriState? {
        guard case .text(let string) = self else { return nil }
        return TriState(rawValue: string)
    }

    var measurementUnit: String {
        if case .measurement(_, let unit) = self { return unit }
        return "m²"
    }

    /// Displayed when a value has not been recorded.
    var displayValue: String { isEmpty ? "—" : stringValue }

    private static func trim(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%g", value)
    }
}
