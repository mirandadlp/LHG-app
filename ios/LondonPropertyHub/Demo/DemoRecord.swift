import Foundation

/// One property while the demo is running.
///
/// The server stores base fields in columns and custom fields in rows; here
/// everything lives in one `values` bag keyed by field key, which is the shape
/// the client renders from anyway. Every derived figure below — completeness,
/// missing fields, totals, permissions — reproduces the server's own
/// calculation so the demo cannot quietly disagree with production.
struct DemoProperty: Sendable {
    var id: Int
    var publicId: String
    var verification: VerificationStatus
    var submittedAt: Date?
    var verifiedAt: Date?
    var verificationDueOn: Date?
    var values: [String: FieldValue]
    var accommodation: [String: Int?]
    var elevators: [Elevator]
    var staircases: [Staircase]
    var documents: [PropertyDocument]

    /// Newest first, the way `Property::changeLogs()` orders them.
    var history: [ChangeLogEntry]

    /// Every flag ever raised, resolved or not. The client only ever sees the
    /// pending ones.
    var flags: [ChangeFlag]

    var updatedAt: Date

    // MARK: - Totals

    func count(_ key: String) -> Int { (accommodation[key] ?? nil) ?? 0 }

    func sum(of keys: [String]) -> Int { keys.reduce(0) { $0 + count($1) } }

    var totalUnits: Int { sum(of: DemoRegistry.accommodationKeys) }

    var flatsTotal: Int { sum(of: DemoRegistry.flatKeys) }

    var housesTotal: Int { sum(of: DemoRegistry.houseKeys) }

    var siteName: String { values["siteName"]?.stringValue ?? "" }

    var fullAddress: String {
        ["addressLine1", "addressLine2", "city", "postcode"]
            .compactMap { values[$0]?.stringValue }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var pendingFlags: [ChangeFlag] { flags.filter { $0.resolution == "Pending" } }

    var pendingApprovalCount: Int { history.filter { $0.approval == "Pending" }.count }

    var lastUpdatedLabel: String? { history.first?.date }

    // MARK: - Derived figures

    /// Percentage of the record that is filled in: every applicable field counts
    /// once, plus three structural checks for accommodation, lifts and stairs.
    func completeness(fields: [FieldDefinition]) -> Int {
        let total = fields.count + 3

        guard total > 0 else { return 0 }

        var filled = fields.filter { !(values[$0.key] ?? .empty).isEmpty }.count

        if totalUnits > 0 { filled += 1 }
        if !elevators.isEmpty { filled += 1 }
        if !staircases.isEmpty { filled += 1 }

        return Int((Double(filled) / Double(total) * 100).rounded())
    }

    func missing(fields: [FieldDefinition]) -> PropertyDetail.Missing {
        var required: [PropertyDetail.MissingField] = []
        var optional: [PropertyDetail.MissingField] = []

        for field in fields where (values[field.key] ?? .empty).isEmpty {
            let entry = PropertyDetail.MissingField(key: field.key, label: field.label, section: field.section)

            if field.required {
                required.append(entry)
            } else {
                optional.append(entry)
            }
        }

        return PropertyDetail.Missing(required: required, optional: optional)
    }

    // MARK: - Permissions

    /// `PropertyPolicy`, in Swift. Corporate does everything; a manager touches
    /// only the properties they are named on and only until they submit;
    /// leadership writes nothing.
    func isManaged(by persona: DemoPersona) -> Bool {
        values["managerEmail"]?.stringValue.lowercased() == persona.email.lowercased()
    }

    func canView(_ persona: DemoPersona) -> Bool {
        persona.role != .manager || isManaged(by: persona)
    }

    func canEdit(_ persona: DemoPersona) -> Bool {
        switch persona.role {
        case .admin:
            return true
        case .leadership:
            return false
        case .manager:
            return isManaged(by: persona) && verification != .submitted
        }
    }

    func canSubmit(_ persona: DemoPersona) -> Bool {
        guard verification != .submitted else { return false }

        return persona.role == .admin || (persona.role == .manager && isManaged(by: persona))
    }

    func canReview(_ persona: DemoPersona) -> Bool { persona.role == .admin }

    func canDelete(_ persona: DemoPersona) -> Bool { persona.role == .admin }

    // MARK: - Client shapes

    func summary(fields: [FieldDefinition]) -> PropertySummary {
        PropertySummary(
            id: id,
            publicId: publicId,
            siteName: siteName.isEmpty ? "Untitled property" : siteName,
            propertyName: values["propertyName"]?.stringValue,
            address: fullAddress,
            borough: values["borough"]?.stringValue,
            council: values["council"]?.stringValue,
            region: values["region"]?.stringValue,
            propertyType: values["propertyType"]?.stringValue,
            operationalStatus: values["operationalStatus"]?.stringValue,
            manager: values["manager"]?.stringValue,
            managerEmail: values["managerEmail"]?.stringValue,
            verification: verification,
            totalUnits: totalUnits,
            elevatorCount: elevators.count,
            staircaseCount: staircases.count,
            documentCount: documents.count,
            floors: values["floors"]?.intValue,
            accessibleBedroomCount: values["accessibleBedroomCount"]?.intValue,
            stepFree: values["stepFree"]?.stringValue,
            completeness: completeness(fields: fields),
            openFlagCount: pendingFlags.count,
            lastUpdated: lastUpdatedLabel,
            updatedAt: DemoFormat.iso(updatedAt)
        )
    }

    func detail(fields: [FieldDefinition], persona: DemoPersona) -> PropertyDetail {
        // A field added after this record was written reads as empty rather
        // than as missing, exactly as the server seeds the bag.
        var bag = values

        for field in fields where bag[field.key] == nil {
            bag[field.key] = .empty
        }

        return PropertyDetail(
            id: id,
            publicId: publicId,
            verification: verification,
            submittedAt: submittedAt.map(DemoFormat.iso),
            verifiedAt: verifiedAt.map(DemoFormat.iso),
            verificationDueOn: verificationDueOn.map(DemoFormat.day),
            values: bag,
            accommodation: accommodation,
            totalUnits: totalUnits,
            flatsTotal: flatsTotal,
            housesTotal: housesTotal,
            elevators: elevators,
            staircases: staircases,
            documents: documents,
            history: history,
            flags: pendingFlags,
            completeness: completeness(fields: fields),
            missing: missing(fields: fields),
            pendingApprovalCount: pendingApprovalCount,
            permissions: PropertyDetail.Permissions(
                canEdit: canEdit(persona),
                canSubmit: canSubmit(persona),
                canReview: canReview(persona),
                canDelete: canDelete(persona)
            )
        )
    }
}

// MARK: - Dates

/// The three date shapes the API sends, in one place.
enum DemoFormat {

    /// `2026-08-12 09:41` — audit rows.
    static func stamp(_ date: Date) -> String { stampFormatter.string(from: date) }

    /// `2026-08-12` — document dates and verification due dates.
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// ISO 8601 — timestamps the client only ever passes through.
    static func iso(_ date: Date) -> String { date.ISO8601Format() }

    /// Parses the date shapes the app writes: `yyyy-MM-dd`, and the
    /// `yyyy-MM-dd HH:mm(:ss)` stamps in the audit trail. Returns nil for
    /// anything else, which is how the date field is validated.
    static func parseStrict(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return dayFormatter.date(from: trimmed)
            ?? stampFormatter.date(from: trimmed)
            ?? seedFormatter.date(from: trimmed)
    }

    static func daysAgo(_ days: Int) -> Date {
        Date().addingTimeInterval(-Double(days) * 86_400)
    }

    static func daysAhead(_ days: Int) -> Date {
        Date().addingTimeInterval(Double(days) * 86_400)
    }

    private static let stampFormatter = FixedFormatter("yyyy-MM-dd HH:mm")
    private static let dayFormatter = FixedFormatter("yyyy-MM-dd")
    private static let seedFormatter = FixedFormatter("yyyy-MM-dd HH:mm:ss")
}

/// A `DateFormatter` behind a Sendable front.
///
/// `DateFormatter` has been safe to *use* from several threads since iOS 7; what
/// is unsafe is reconfiguring one after the fact, which this box makes
/// impossible. Sharing one per shape beats rebuilding a formatter for every
/// audit row the demo renders.
private struct FixedFormatter: @unchecked Sendable {
    private let formatter: DateFormatter

    init(_ format: String) {
        formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
    }

    func string(from date: Date) -> String { formatter.string(from: date) }

    func date(from value: String) -> Date? { formatter.date(from: value) }
}
