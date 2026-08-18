import Foundation

// MARK: - List shape

/// The lightweight record behind directory cards, search results and the
/// approvals queue.
struct PropertySummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let publicId: String
    let siteName: String
    let propertyName: String?
    let address: String
    let borough: String?
    let council: String?
    let region: String?
    let propertyType: String?
    let operationalStatus: String?
    let manager: String?
    let managerEmail: String?
    let verification: VerificationStatus
    let totalUnits: Int
    let elevatorCount: Int
    let staircaseCount: Int
    let documentCount: Int
    let floors: Int?
    let accessibleBedroomCount: Int?
    let stepFree: String?
    let completeness: Int
    let openFlagCount: Int
    let lastUpdated: String?
    let updatedAt: String?

    var managerLabel: String { manager?.isEmpty == false ? manager! : "Unassigned" }
    var floorsLabel: String { floors.map(String.init) ?? "—" }
}

// MARK: - Full record

struct PropertyDetail: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let publicId: String
    let verification: VerificationStatus
    let submittedAt: String?
    let verifiedAt: String?
    let verificationDueOn: String?

    /// Keyed by field key — rendered against the registry from /bootstrap.
    var values: [String: FieldValue]

    var accommodation: [String: Int?]
    let totalUnits: Int
    let flatsTotal: Int
    let housesTotal: Int

    var elevators: [Elevator]
    var staircases: [Staircase]
    var documents: [PropertyDocument]
    var history: [ChangeLogEntry]
    var flags: [ChangeFlag]

    let completeness: Int
    let missing: Missing
    let pendingApprovalCount: Int
    let permissions: Permissions

    struct Missing: Codable, Hashable, Sendable {
        let required: [MissingField]
        let optional: [MissingField]
    }

    struct MissingField: Codable, Hashable, Identifiable, Sendable {
        let key: String
        let label: String
        let section: FieldSection

        var id: String { key }
    }

    struct Permissions: Codable, Hashable, Sendable {
        let canEdit: Bool
        let canSubmit: Bool
        let canReview: Bool
        let canDelete: Bool
    }

    // MARK: Convenience

    var siteName: String {
        let name = values["siteName"]?.stringValue ?? ""
        return name.isEmpty ? "Untitled property" : name
    }

    var fullAddress: String {
        let parts = ["addressLine1", "addressLine2", "city", "postcode"]
            .compactMap { values[$0]?.stringValue }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "No address recorded" : parts.joined(separator: ", ")
    }

    var managerLabel: String {
        let name = values["manager"]?.stringValue ?? ""
        return name.isEmpty ? "Unassigned" : name
    }

    func count(_ key: String) -> Int {
        (accommodation[key] ?? nil) ?? 0
    }

    /// Sum a set of accommodation keys, treating blanks as zero.
    func sum(of keys: [String]) -> Int {
        keys.reduce(0) { $0 + count($1) }
    }
}

// MARK: - Sub-records

struct Elevator: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
    var type: String
    var capacity: Int?
    var maxOccupancy: Int?
    var width: Double?
    var depth: Double?
    var height: Double?
    var doorWidth: Double?
    var accessible: TriState
    var service: TriState
    var passenger: TriState
    var notes: String
    let position: Int

    var displayName: String { name.isEmpty ? "Unnamed lift" : name }
}

struct Staircase: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    var name: String
    var location: String
    var floorsServed: Int?
    var width: Double?
    var classification: String
    var emergencyExit: TriState
    var notes: String
    let position: Int

    static let classifications = [
        "Standard", "Accessible", "Emergency", "Accessible & Emergency",
    ]

    var displayName: String { name.isEmpty ? "Unnamed staircase" : name }
}

struct PropertyDocument: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let type: String
    let date: String?
    let by: String?
    let notes: String
    let sizeBytes: Int?
    let mimeType: String?
    let downloadUrl: String

    var sizeLabel: String {
        guard let sizeBytes else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

struct ChangeLogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let field: String
    let prev: String
    let next: String
    let by: String
    let date: String?
    let reason: String?
    let approval: String

    var isApproved: Bool { approval == "Approved" }
}

struct ChangeFlag: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let key: String
    let label: String
    let prev: Int
    let next: Int
    let resolution: String
    let raisedAt: String?
}

// MARK: - Dashboard

struct DashboardPayload: Codable, Sendable {
    let totals: Totals
    let byBorough: [BoroughUnits]
    let byStatus: [StatusCount]
    let needsAttention: [PropertySummary]
    let filterActive: Bool

    struct Totals: Codable, Sendable {
        let properties: Int
        let units: Int
        let singles: Int
        let doubles: Int
        let triples: Int
        let wcSc: Int
        let flats: Int
        let houses: Int
        let lifts: Int
        let staircases: Int
        let accessibleRooms: Int
        let verified: Int
        let awaiting: Int
        let avgComplete: Int
    }

    struct BoroughUnits: Codable, Identifiable, Hashable, Sendable {
        let name: String
        let units: Int

        var id: String { name }
    }

    struct StatusCount: Codable, Identifiable, Hashable, Sendable {
        let name: String
        let value: Int

        var id: String { name }
        var status: VerificationStatus { VerificationStatus(rawValue: name) ?? .notStarted }
    }
}

// MARK: - Bootstrap

struct BootstrapPayload: Codable, Sendable {
    let user: CurrentUser
    let sections: [SectionDescriptor]
    let fields: [FieldDefinition]
    let options: [String: [String]]
    let accommodationTypes: [AccommodationType]
    let accommodationGroups: [String]
    let verificationStatuses: [String]
    let measurementUnits: [String]
    let reportColumns: [String]
    let defaultReportColumns: [String]

    struct SectionDescriptor: Codable, Identifiable, Sendable {
        let id: String
        let label: String
    }
}

// MARK: - Reports

struct ReportPayload: Codable, Sendable {
    let columns: [String]
    let availableColumns: [String]
    let rows: [[String: ReportCell]]
    let totals: [String: ReportCell]
    let propertyCount: Int
    let unitCount: Int
    let filterActive: Bool
}

/// Report cells arrive as either a string or a number depending on the column.
enum ReportCell: Codable, Hashable, Sendable {
    case text(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .text(string)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string): try container.encode(string)
        case .number(let number): try container.encode(number)
        }
    }

    var display: String {
        switch self {
        case .text(let string): return string
        case .number(let number):
            return number == number.rounded() ? Int(number).formattedCount : String(format: "%g", number)
        }
    }
}

// MARK: - Import

struct ImportParse: Codable, Sendable {
    let fileName: String
    let headers: [String]
    let rows: [[String: ReportCell]]
    var mapping: [String: String]
    let targets: [ImportTarget]
    var preview: [ImportPreviewRow]
}

struct ImportTarget: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let label: String
}

struct ImportPreviewRow: Codable, Identifiable, Hashable, Sendable {
    let index: Int
    let values: [String: FieldValue]
    let accommodation: [String: Int?]
    let totalUnits: Int
    let duplicate: Bool
    let duplicateReason: String?
    let missingRequired: [String]
    let importable: Bool

    var id: Int { index }
    var siteName: String { values["siteName"]?.stringValue ?? "" }
    var borough: String { values["borough"]?.stringValue ?? "—" }
}

struct ImportResult: Codable, Sendable {
    let message: String
    let imported: [PropertySummary]
    let skipped: Int
}
