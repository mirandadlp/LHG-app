import Foundation

/// The whole API, in memory.
///
/// One actor holds the demo portfolio and answers every call `PropertyAPI`
/// would otherwise send over the network. It is not a stub: it enforces the
/// same role rules, refuses the same invalid values, writes the same audit
/// rows, raises the same large-change flags and recomputes completeness the
/// same way. Anything the real API would reject, this rejects too — otherwise
/// the demo would teach the wrong lessons about the product.
///
/// State lives for as long as the process does. Signing out, or relaunching the
/// app, starts from the seed again.
actor DemoBackend {

    static let shared = DemoBackend()

    /// While this is false, `PropertyAPI` behaves exactly as it always has.
    private(set) var isActive = false

    /// Readable by the report and import extensions, which live in their own
    /// files and so cannot see anything file-private here.
    private(set) var persona: DemoPersona = .admin
    private var properties: [DemoProperty] = []
    private var customFields: [FieldDefinition] = DemoRegistry.seededCustomFields
    private var options: [String: [String]] = DemoRegistry.optionLists

    /// Bytes for documents added during the demo, so downloading one gives back
    /// the file that went in rather than a stand-in.
    private var uploadedDocuments: [Int: Data] = [:]

    private var nextPropertyID = 100
    private var nextElevatorID = 1000
    private var nextStaircaseID = 2000
    private var nextDocumentID = 3000
    private var nextLogID = 4000
    private var nextFlagID = 5000
    private var nextFieldID = 100

    private init() {}

    // MARK: - Session

    func signIn(as persona: DemoPersona) -> PropertyAPI.LoginResponse {
        activate(as: persona)

        return PropertyAPI.LoginResponse(
            token: DemoAccount.token(for: persona),
            expiresAt: nil,
            user: persona.currentUser
        )
    }

    /// Called at launch. A demo token in the Keychain means the last session was
    /// a demo one, so the app comes back up in demo mode rather than trying to
    /// reach a server with a token no server ever issued.
    func restoreIfNeeded() async {
        guard !isActive else { return }

        // The token itself says which persona was signed in, so there is no
        // second copy of that fact to fall out of step.
        guard let persona = DemoAccount.persona(forToken: await APIClient.shared.token) else { return }

        activate(as: persona)
    }

    func signOut() {
        isActive = false
        properties = []
        uploadedDocuments = [:]
    }

    /// Throw the edits away and start the tour again from the seed.
    func reset() {
        activate(as: persona)
    }

    private func activate(as persona: DemoPersona) {
        self.persona = persona
        self.properties = DemoSeed.portfolio()
        self.customFields = DemoRegistry.seededCustomFields
        self.options = DemoRegistry.optionLists
        self.uploadedDocuments = [:]
        self.isActive = true
    }

    var currentUser: CurrentUser { persona.currentUser }

    // MARK: - Registry

    /// Base fields first, then whatever corporate has added, exactly as
    /// `FieldDefinition::activeDefinitions()` orders them.
    var fields: [FieldDefinition] { DemoRegistry.baseFields + customFields }

    func bootstrap() -> BootstrapPayload {
        BootstrapPayload(
            user: persona.currentUser,
            sections: DemoRegistry.sections,
            fields: fields,
            options: options,
            accommodationTypes: DemoRegistry.accommodationTypes,
            accommodationGroups: DemoRegistry.accommodationGroups,
            verificationStatuses: DemoRegistry.verificationStatuses,
            measurementUnits: DemoRegistry.measurementUnits,
            reportColumns: DemoRegistry.allReportColumns,
            defaultReportColumns: DemoRegistry.defaultReportColumns
        )
    }

    // MARK: - Reading properties

    /// The role-scoped, filtered set every list screen renders from, ordered by
    /// site name the way the index endpoint orders it.
    func visibleProperties(filters: PropertyFilters) -> [DemoProperty] {
        properties
            .filter { $0.canView(persona) }
            .filter { matches($0, filters) }
            .sorted { $0.siteName.localizedCaseInsensitiveCompare($1.siteName) == .orderedAscending }
    }

    func summaries(filters: PropertyFilters) -> [PropertySummary] {
        let definitions = fields

        return visibleProperties(filters: filters).map { $0.summary(fields: definitions) }
    }

    func detail(id: Int) throws -> PropertyDetail {
        try stored(id).detail(fields: fields, persona: persona)
    }

    private func matches(_ property: DemoProperty, _ filters: PropertyFilters) -> Bool {
        func equals(_ key: String, _ expected: String) -> Bool {
            expected.isEmpty || property.values[key]?.stringValue == expected
        }

        guard
            equals("borough", filters.borough),
            equals("council", filters.council),
            equals("region", filters.region),
            equals("propertyType", filters.propertyType)
        else {
            return false
        }

        if !filters.verification.isEmpty, property.verification.rawValue != filters.verification {
            return false
        }

        let term = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !term.isEmpty else { return true }

        // The same ten columns the server searches.
        return [
            "siteName", "propertyName", "addressLine1", "addressLine2",
            "city", "postcode", "borough", "council", "region", "manager",
        ].contains { key in
            property.values[key]?.stringValue.localizedCaseInsensitiveContains(term) ?? false
        }
    }

    private func stored(_ id: Int) throws -> DemoProperty {
        try properties[index(of: id)]
    }

    private func index(of id: Int) throws -> Int {
        guard let index = properties.firstIndex(where: { $0.id == id }) else {
            throw APIError.notFound
        }

        guard properties[index].canView(persona) else {
            throw APIError.forbidden("You can only open the properties you are named on.")
        }

        return index
    }

    /// The reason an edit is refused, phrased the way the server phrases it.
    private func assertEditable(_ property: DemoProperty) throws {
        if property.canEdit(persona) { return }

        switch persona.role {
        case .leadership:
            throw APIError.forbidden("Leadership accounts have read-only access.")
        case .manager where property.verification == .submitted:
            throw APIError.forbidden("This record is locked while corporate reviews it.")
        default:
            throw APIError.forbidden("Your role does not permit this action.")
        }
    }

    // MARK: - Writing field values

    /// The importer passes `validate: false`, matching the server: a legacy
    /// spreadsheet is written as it stands and corrected afterwards, rather
    /// than having a whole file rejected over one malformed postcode.
    func createProperty(values: [String: FieldValue], validate shouldValidate: Bool = true) throws -> PropertyDetail {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can add a property.")
        }

        let siteName = values["siteName"]?.stringValue ?? ""

        guard !siteName.isEmpty else {
            throw APIError.validation(
                message: "The site name field is required.",
                fields: ["values.siteName": ["The site name field is required."]]
            )
        }

        if shouldValidate {
            try validate(values)
        }

        nextPropertyID += 1

        var property = DemoProperty(
            id: nextPropertyID,
            publicId: UUID().uuidString.lowercased(),
            verification: .notStarted,
            submittedAt: nil,
            verifiedAt: nil,
            verificationDueOn: nil,
            values: [:],
            accommodation: Dictionary(uniqueKeysWithValues: DemoRegistry.accommodationKeys.map { ($0, Int?.none) }),
            elevators: [],
            staircases: [],
            documents: [],
            history: [],
            flags: [],
            updatedAt: Date()
        )

        apply(values, to: &property, reason: "New property added")
        record(&property, field: "Property record", from: "—", to: "Created", reason: "New property added")

        // A brand new record has not been verified by anyone yet, whatever was
        // typed into it — writing values would otherwise mark it In Progress.
        property.verification = .notStarted
        properties.append(property)

        return property.detail(fields: fields, persona: persona)
    }

    func updateProperty(id: Int, values: [String: FieldValue], reason: String?) throws -> PropertyDetail {
        let index = try index(of: id)

        try assertEditable(properties[index])
        try validate(values)

        apply(values, to: &properties[index], reason: reason)

        return properties[index].detail(fields: fields, persona: persona)
    }

    func deleteProperty(id: Int) throws -> MessageResponse {
        let index = try index(of: id)

        guard properties[index].canDelete(persona) else {
            throw APIError.forbidden("Only a corporate administrator can remove a property.")
        }

        let name = properties[index].siteName
        properties.remove(at: index)

        return MessageResponse(message: "\(name) removed.")
    }

    /// Writes the values that actually changed, one audit row each.
    private func apply(_ values: [String: FieldValue], to property: inout DemoProperty, reason: String?) {
        let definitions = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0) })
        var wrote = false

        for (key, value) in values {
            guard let definition = definitions[key] else { continue }

            let previous = property.values[key] ?? .empty

            guard display(previous) != display(value) else { continue }

            property.values[key] = value
            wrote = true

            record(
                &property,
                field: definition.label,
                from: display(previous),
                to: display(value),
                reason: reason,
                approval: "Pending"
            )
        }

        if wrote {
            touchProgress(&property)
        }
    }

    /// Site names already in the portfolio, for duplicate detection on import.
    var existingSiteNames: Set<String> {
        Set(properties.map { $0.siteName.lowercased() })
    }

    /// An imported record starts Not Started — nothing in it has been verified
    /// by a human yet, whatever the spreadsheet claimed. This runs after the
    /// values are written, which would otherwise have marked it In Progress.
    func markImported(id: Int) throws -> PropertySummary {
        let index = try index(of: id)

        properties[index].verification = .notStarted

        return properties[index].summary(fields: fields)
    }

    // MARK: - Accommodation

    func updateAccommodation(id: Int, counts: [String: Int?], reason: String?) throws -> PropertyDetail {
        let index = try index(of: id)

        try assertEditable(properties[index])

        applyAccommodation(counts, to: &properties[index], reason: reason, detectLargeChanges: true)

        return properties[index].detail(fields: fields, persona: persona)
    }

    private func applyAccommodation(
        _ counts: [String: Int?],
        to property: inout DemoProperty,
        reason: String?,
        detectLargeChanges: Bool
    ) {
        var wrote = false

        for (key, value) in counts {
            guard DemoRegistry.accommodationKeys.contains(key) else { continue }

            let previous = property.count(key)
            let next = value.map { max(0, $0) }

            guard previous != (next ?? 0) else { continue }

            property.accommodation.updateValue(next, forKey: key)
            wrote = true

            record(
                &property,
                field: DemoRegistry.accommodationLabel(key),
                from: String(previous),
                to: String(next ?? 0),
                reason: reason,
                approval: "Pending"
            )

            if detectLargeChanges, DemoRegistry.isLargeChange(previous: previous, next: next ?? 0) {
                raiseFlag(on: &property, key: key, previous: previous, next: next ?? 0)
            }
        }

        if wrote {
            touchProgress(&property)
        }
    }

    private func raiseFlag(on property: inout DemoProperty, key: String, previous: Int, next: Int) {
        // Only the latest movement on a field matters; supersede any open flag.
        property.flags.removeAll { $0.key == key && $0.resolution == "Pending" }

        nextFlagID += 1

        property.flags.insert(
            ChangeFlag(
                id: nextFlagID,
                key: key,
                label: DemoRegistry.accommodationLabel(key),
                prev: previous,
                next: next,
                resolution: "Pending",
                raisedAt: DemoFormat.iso(Date())
            ),
            at: 0
        )
    }

    func resolveFlag(propertyID: Int, flagID: Int, confirm: Bool) throws -> PropertyDetail {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        guard let flagIndex = properties[index].flags.firstIndex(where: { $0.id == flagID }) else {
            throw APIError.notFound
        }

        let flag = properties[index].flags[flagIndex]

        if !confirm {
            // Putting the old figure back writes its own audit row, and must not
            // itself be flagged or the two would chase each other forever.
            applyAccommodation(
                [flag.key: flag.prev],
                to: &properties[index],
                reason: "Reverted after large-change review",
                detectLargeChanges: false
            )
        }

        properties[index].flags[flagIndex] = ChangeFlag(
            id: flag.id,
            key: flag.key,
            label: flag.label,
            prev: flag.prev,
            next: flag.next,
            resolution: confirm ? "Confirmed" : "Reverted",
            raisedAt: flag.raisedAt
        )

        return properties[index].detail(fields: fields, persona: persona)
    }

    // MARK: - Verification workflow

    func submit(id: Int) throws -> PropertyDetail {
        let index = try index(of: id)

        guard properties[index].canSubmit(persona) else {
            throw APIError.forbidden(
                properties[index].verification == .submitted
                    ? "This record has already been submitted."
                    : "Only the property manager named on this record can submit it."
            )
        }

        let missing = properties[index].missing(fields: fields).required

        guard missing.isEmpty else {
            throw APIError.validation(
                message: "Complete the required fields before submitting.",
                fields: [:]
            )
        }

        let previous = properties[index].verification

        properties[index].verification = .submitted
        properties[index].submittedAt = Date()

        record(
            &properties[index],
            field: "Verification",
            from: previous.rawValue,
            to: VerificationStatus.submitted.rawValue,
            reason: "Submitted for review by property manager",
            approval: "Approved"
        )

        return properties[index].detail(fields: fields, persona: persona)
    }

    func approve(id: Int, comment: String?) throws -> PropertyDetail {
        let index = try index(of: id)

        try assertReviewer(properties[index])

        let previous = properties[index].verification

        properties[index].verification = .verified
        properties[index].verifiedAt = Date()
        properties[index].submittedAt = nil
        properties[index].verificationDueOn = DemoFormat.daysAhead(180)

        record(
            &properties[index],
            field: "Verification",
            from: previous.rawValue,
            to: VerificationStatus.verified.rawValue,
            reason: trimmed(comment) ?? "Approved by corporate",
            approval: "Approved"
        )

        // Approving the record approves the edits that made it up.
        properties[index].history = properties[index].history.map { entry in
            guard entry.approval == "Pending" else { return entry }

            return ChangeLogEntry(
                id: entry.id, field: entry.field, prev: entry.prev, next: entry.next,
                by: entry.by, date: entry.date, reason: entry.reason, approval: "Approved"
            )
        }

        return properties[index].detail(fields: fields, persona: persona)
    }

    func requestChanges(id: Int, comment: String?) throws -> PropertyDetail {
        let index = try index(of: id)

        try assertReviewer(properties[index])

        let previous = properties[index].verification

        properties[index].verification = .changesRequested
        properties[index].submittedAt = nil

        record(
            &properties[index],
            field: "Verification",
            from: previous.rawValue,
            to: VerificationStatus.changesRequested.rawValue,
            reason: trimmed(comment) ?? "Changes requested by corporate",
            approval: "Approved"
        )

        return properties[index].detail(fields: fields, persona: persona)
    }

    func requestVerification(id: Int) throws -> PropertyDetail {
        let index = try index(of: id)

        try assertReviewer(properties[index])

        let previous = properties[index].verification

        properties[index].verification = .inProgress
        properties[index].verificationDueOn = DemoFormat.daysAhead(30)

        record(
            &properties[index],
            field: "Verification",
            from: previous.rawValue,
            to: VerificationStatus.inProgress.rawValue,
            reason: "Verification requested",
            approval: "Approved"
        )

        return properties[index].detail(fields: fields, persona: persona)
    }

    private func assertReviewer(_ property: DemoProperty) throws {
        guard property.canReview(persona) else {
            throw APIError.forbidden("Approving a submission is a corporate administrator's decision.")
        }
    }

    // MARK: - Lifts and stairs

    func addElevator(propertyID: Int) throws -> Elevator {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let before = properties[index].elevators.count
        nextElevatorID += 1

        let elevator = Elevator(
            id: nextElevatorID, name: "Lift \(before + 1)", type: "Passenger",
            capacity: nil, maxOccupancy: nil, width: nil, depth: nil, height: nil, doorWidth: nil,
            accessible: .yes, service: .no, passenger: .yes, notes: "", position: before
        )

        properties[index].elevators.append(elevator)
        record(&properties[index], field: "Elevators", from: String(before), to: String(before + 1),
               reason: "Record added", approval: "Pending")

        return elevator
    }

    func updateElevator(propertyID: Int, elevator: Elevator) throws -> Elevator {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        guard let position = properties[index].elevators.firstIndex(where: { $0.id == elevator.id }) else {
            throw APIError.notFound
        }

        properties[index].elevators[position] = elevator
        properties[index].updatedAt = Date()

        return elevator
    }

    func deleteElevator(propertyID: Int, elevatorID: Int) throws -> MessageResponse {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let before = properties[index].elevators.count
        properties[index].elevators.removeAll { $0.id == elevatorID }

        guard properties[index].elevators.count < before else { throw APIError.notFound }

        record(&properties[index], field: "Elevators", from: String(before), to: String(before - 1),
               reason: "Record removed", approval: "Pending")

        return MessageResponse(message: "Elevator removed.")
    }

    func addStaircase(propertyID: Int) throws -> Staircase {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let before = properties[index].staircases.count
        nextStaircaseID += 1

        let staircase = Staircase(
            id: nextStaircaseID, name: "Stair \(before + 1)", location: "", floorsServed: nil,
            width: nil, classification: "Standard", emergencyExit: .no, notes: "", position: before
        )

        properties[index].staircases.append(staircase)
        record(&properties[index], field: "Staircases", from: String(before), to: String(before + 1),
               reason: "Record added", approval: "Pending")

        return staircase
    }

    func updateStaircase(propertyID: Int, staircase: Staircase) throws -> Staircase {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        guard let position = properties[index].staircases.firstIndex(where: { $0.id == staircase.id }) else {
            throw APIError.notFound
        }

        properties[index].staircases[position] = staircase
        properties[index].updatedAt = Date()

        return staircase
    }

    func deleteStaircase(propertyID: Int, staircaseID: Int) throws -> MessageResponse {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let before = properties[index].staircases.count
        properties[index].staircases.removeAll { $0.id == staircaseID }

        guard properties[index].staircases.count < before else { throw APIError.notFound }

        record(&properties[index], field: "Staircases", from: String(before), to: String(before - 1),
               reason: "Record removed", approval: "Pending")

        return MessageResponse(message: "Staircase removed.")
    }

    // MARK: - Documents

    func uploadDocument(propertyID: Int, fileURL: URL, type: String, notes: String) throws -> PropertyDocument {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let allowed = ["pdf", "jpg", "jpeg", "png", "heic", "webp",
                       "doc", "docx", "xls", "xlsx", "csv", "txt", "dwg", "dxf"]
        let ext = fileURL.pathExtension.lowercased()

        guard allowed.contains(ext) else {
            throw APIError.validation(
                message: "The file must be one of: \(allowed.joined(separator: ", ")).",
                fields: ["file": ["Unsupported file type."]]
            )
        }

        let needsScope = fileURL.startAccessingSecurityScopedResource()

        defer { if needsScope { fileURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: fileURL) else {
            throw APIError.unknown("That file could not be read.")
        }

        guard data.count <= 20 * 1024 * 1024 else {
            throw APIError.validation(
                message: "The file may not be greater than 20 MB.",
                fields: ["file": ["The file is too large."]]
            )
        }

        nextDocumentID += 1

        let document = PropertyDocument(
            id: nextDocumentID,
            name: fileURL.lastPathComponent,
            type: type,
            date: DemoFormat.day(Date()),
            by: persona.name,
            notes: notes,
            sizeBytes: data.count,
            mimeType: DemoFiles.mimeType(forExtension: ext),
            downloadUrl: "demo://documents/\(nextDocumentID)"
        )

        uploadedDocuments[document.id] = data

        let before = properties[index].documents.count
        properties[index].documents.insert(document, at: 0)

        record(&properties[index], field: "Documents", from: String(before), to: String(before + 1),
               reason: "Document uploaded", approval: "Pending")

        return document
    }

    func deleteDocument(propertyID: Int, documentID: Int) throws -> MessageResponse {
        let index = try index(of: propertyID)

        try assertEditable(properties[index])

        let before = properties[index].documents.count
        properties[index].documents.removeAll { $0.id == documentID }

        guard properties[index].documents.count < before else { throw APIError.notFound }

        uploadedDocuments[documentID] = nil

        record(&properties[index], field: "Documents", from: String(before), to: String(before - 1),
               reason: "Document removed", approval: "Pending")

        return MessageResponse(message: "Document removed.")
    }

    /// Hands back the bytes that were uploaded during this session; a seeded
    /// document, which never had any, comes back as a one-page PDF saying so.
    func downloadDocument(_ document: PropertyDocument) async throws -> URL {
        if let data = uploadedDocuments[document.id] {
            return try DemoFiles.write(data, named: document.name)
        }

        return try await DemoFiles.placeholderPDF(named: document.name, type: document.type)
    }

    // MARK: - Custom fields and option lists

    func createField(_ body: PropertyAPI.NewFieldBody) throws -> PropertyAPI.FieldsResponse {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can add a field.")
        }

        let label = body.label.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !label.isEmpty else {
            throw APIError.validation(
                message: "The label field is required.",
                fields: ["label": ["The label field is required."]]
            )
        }

        nextFieldID += 1

        let definition = FieldDefinition(
            definitionId: nextFieldID,
            key: uniqueKey(for: label),
            section: FieldSection(rawValue: body.section) ?? .general,
            label: label,
            // "dropdown" is the word the builder shows; the stored type is
            // custom-select, which carries its own inline option list.
            type: FieldType(rawValue: body.type == "dropdown" ? "custom-select" : body.type) ?? .text,
            required: body.required,
            help: body.help,
            unit: body.unit,
            optionListKey: nil,
            optionList: body.optionList,
            custom: true
        )

        customFields.append(definition)

        return PropertyAPI.FieldsResponse(
            message: "\"\(label)\" is now collected on every property record.",
            fields: fields
        )
    }

    func deleteField(definitionID: Int) throws -> PropertyAPI.FieldsResponse {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can remove a field.")
        }

        guard let index = customFields.firstIndex(where: { $0.definitionId == definitionID }) else {
            throw APIError.notFound
        }

        let removed = customFields.remove(at: index)

        // Removing a field removes every value stored under it.
        for propertyIndex in properties.indices {
            properties[propertyIndex].values[removed.key] = nil
        }

        return PropertyAPI.FieldsResponse(
            message: "\"\(removed.label)\" removed from the record.",
            fields: fields
        )
    }

    func addOption(list: String, value: String) throws -> PropertyAPI.OptionsResponse {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can change a list.")
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw APIError.validation(
                message: "The value field is required.",
                fields: ["value": ["The value field is required."]]
            )
        }

        var values = options[list] ?? []

        if !values.contains(trimmed) {
            values.append(trimmed)
            options[list] = values
        }

        return PropertyAPI.OptionsResponse(options: options)
    }

    func removeOption(list: String, value: String) throws -> PropertyAPI.OptionsResponse {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can change a list.")
        }

        options[list]?.removeAll { $0 == value }

        return PropertyAPI.OptionsResponse(options: options)
    }

    private func uniqueKey(for label: String) -> String {
        let slug = label.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "_" }
            .reduce(into: "") { result, character in
                // Collapse runs of separators the way a slug helper would.
                if character == "_", result.last == "_" { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        var key = "cf_" + String(slug.prefix(40))
        var suffix = 2
        let taken = Set(fields.map(\.key))

        while taken.contains(key) {
            key = "cf_" + String(slug.prefix(40)) + "_\(suffix)"
            suffix += 1
        }

        return key
    }

    // MARK: - Audit trail

    private func record(
        _ property: inout DemoProperty,
        field: String,
        from previous: String,
        to next: String,
        reason: String?,
        approval: String = "Pending"
    ) {
        nextLogID += 1

        property.history.insert(
            ChangeLogEntry(
                id: nextLogID,
                field: field,
                prev: previous,
                next: next,
                by: persona.name,
                date: DemoFormat.stamp(Date()),
                reason: trimmed(reason) ?? defaultReason,
                approval: approval
            ),
            at: 0
        )

        property.updatedAt = Date()
    }

    /// A record being edited for the first time moves off "Not Started".
    private func touchProgress(_ property: inout DemoProperty) {
        if property.verification == .notStarted {
            property.verification = .inProgress
        }
    }

    private var defaultReason: String {
        persona.role == .manager ? "Property manager verification" : "Corporate administrator edit"
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? nil : trimmed
    }

    /// How a value reads in the audit trail: `—` when there is nothing there.
    private func display(_ value: FieldValue) -> String {
        value.isEmpty ? "—" : value.stringValue
    }

    // MARK: - Validation

    /// `UpdatePropertyRequest`, in Swift. Clearing a field is always allowed;
    /// required-ness is enforced at submit, not at every keystroke.
    private func validate(_ values: [String: FieldValue]) throws {
        let definitions = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0) })
        var errors: [String: [String]] = [:]

        func fail(_ key: String, _ message: String) {
            errors["values.\(key)", default: []].append(message)
        }

        for (key, value) in values {
            guard let definition = definitions[key] else {
                fail(key, "Unknown field '\(key)'.")
                continue
            }

            guard !value.isEmpty else { continue }

            let label = definition.label

            switch definition.type {
            case .number:
                if let number = value.doubleValue {
                    if number < 0 || number != number.rounded() {
                        fail(key, "\(label) must be a whole number of zero or more.")
                    }
                } else {
                    fail(key, "\(label) must be a whole number of zero or more.")
                }

            case .decimal:
                if value.doubleValue == nil {
                    fail(key, "\(label) must be a number.")
                }

            case .date:
                if DemoValidation.date(value.stringValue) == nil {
                    fail(key, "\(label) must be a valid date.")
                }

            case .email:
                if !DemoValidation.isEmail(value.stringValue) {
                    fail(key, "\(label) must be a valid email address.")
                }

            case .postcode:
                if !DemoValidation.isUKPostcode(value.stringValue) {
                    fail(key, "\(label) does not look like a UK postcode.")
                }

            case .yesno:
                if value.triState == nil {
                    fail(key, "\(label) must be Yes, No or N/A.")
                }

            case .measurement:
                guard case .measurement(_, let unit) = value else {
                    fail(key, "\(label) must be sent as a value and unit.")
                    continue
                }

                if !DemoRegistry.measurementUnits.contains(unit) {
                    fail(key, "\(label) has an unsupported unit.")
                }

            case .select:
                let allowed = options[definition.optionListKey ?? ""] ?? []

                if !allowed.isEmpty, !allowed.contains(value.stringValue) {
                    fail(key, "\(label) must be one of the configured options.")
                }

            case .customSelect:
                let allowed = definition.optionList ?? []

                if !allowed.isEmpty, !allowed.contains(value.stringValue) {
                    fail(key, "\(label) must be one of the configured options.")
                }

            case .notes:
                if value.stringValue.count > 5000 {
                    fail(key, "\(label) is limited to 5000 characters.")
                }

            case .text:
                if value.stringValue.count > 255 {
                    fail(key, "\(label) is limited to 255 characters.")
                }
            }
        }

        guard errors.isEmpty else {
            throw APIError.validation(
                message: errors.values.first?.first ?? "Some details need correcting.",
                fields: errors
            )
        }
    }
}

// MARK: - Field checks

/// The three format checks the server makes, without pulling in a dependency.
enum DemoValidation {

    static func isEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)

        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let host = parts[1]

        return host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix(".")
            && !value.contains(" ")
    }

    static func isUKPostcode(_ value: String) -> Bool {
        value.range(
            of: "^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    static func date(_ value: String) -> Date? {
        DemoFormat.parseStrict(value)
    }
}
