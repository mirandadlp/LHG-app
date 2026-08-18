import Foundation

/// Every endpoint the app calls, named after what it does rather than the URL
/// it hits. Screens depend on this, never on paths.
struct PropertyAPI {

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Session

    struct LoginResponse: Decodable {
        let token: String
        let expiresAt: String?
        let user: CurrentUser
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        struct Body: Encodable {
            let email: String
            let password: String
            let deviceName: String
        }

        let response = try await client.post(
            "auth/login",
            body: Body(email: email, password: password, deviceName: APIConfiguration.deviceName),
            as: LoginResponse.self
        )

        await client.store(token: response.token)

        return response
    }

    func logout() async {
        // A failed sign-out must still sign the user out locally, or they are
        // stuck on a screen they cannot leave.
        _ = try? await client.post("auth/logout", as: MessageResponse.self)
        await client.clearToken()
    }

    func me() async throws -> CurrentUser {
        try await client.get("auth/me", as: CurrentUser.self)
    }

    func changePassword(current: String, new: String, confirmation: String) async throws -> MessageResponse {
        struct Body: Encodable {
            let currentPassword: String
            let password: String
            let password_confirmation: String
        }

        return try await client.patch(
            "auth/password",
            body: Body(currentPassword: current, password: new, password_confirmation: confirmation),
            as: MessageResponse.self
        )
    }

    // MARK: - Cold start

    func bootstrap() async throws -> BootstrapPayload {
        try await client.get("bootstrap", as: BootstrapPayload.self)
    }

    func dashboard(filters: PropertyFilters) async throws -> DashboardPayload {
        try await client.get("dashboard", query: filters.queryItems, as: DashboardPayload.self)
    }

    // MARK: - Properties

    func properties(filters: PropertyFilters) async throws -> [PropertySummary] {
        try await client.get("properties", query: filters.queryItems, as: [PropertySummary].self)
    }

    func property(id: Int) async throws -> PropertyDetail {
        try await client.get("properties/\(id)", as: PropertyDetail.self)
    }

    struct ValuesBody: Encodable {
        let values: [String: FieldValue]
        let reason: String?
    }

    func createProperty(values: [String: FieldValue]) async throws -> PropertyDetail {
        try await client.post(
            "properties",
            body: ValuesBody(values: values, reason: "New property added"),
            as: PropertyDetail.self
        )
    }

    func updateProperty(id: Int, values: [String: FieldValue], reason: String? = nil) async throws -> PropertyDetail {
        try await client.patch(
            "properties/\(id)",
            body: ValuesBody(values: values, reason: reason),
            as: PropertyDetail.self
        )
    }

    func deleteProperty(id: Int) async throws -> MessageResponse {
        try await client.delete("properties/\(id)", as: MessageResponse.self)
    }

    struct AccommodationBody: Encodable {
        let accommodation: [String: Int?]
        let reason: String?
    }

    func updateAccommodation(
        id: Int,
        counts: [String: Int?],
        reason: String? = nil
    ) async throws -> PropertyDetail {
        try await client.patch(
            "properties/\(id)/accommodation",
            body: AccommodationBody(accommodation: counts, reason: reason),
            as: PropertyDetail.self
        )
    }

    // MARK: - Verification workflow

    func submit(id: Int) async throws -> PropertyDetail {
        try await client.post("properties/\(id)/submit", as: PropertyDetail.self)
    }

    struct CommentBody: Encodable {
        let comment: String?
    }

    func approve(id: Int, comment: String?) async throws -> PropertyDetail {
        try await client.post(
            "properties/\(id)/approve",
            body: CommentBody(comment: comment),
            as: PropertyDetail.self
        )
    }

    func requestChanges(id: Int, comment: String?) async throws -> PropertyDetail {
        try await client.post(
            "properties/\(id)/request-changes",
            body: CommentBody(comment: comment),
            as: PropertyDetail.self
        )
    }

    func requestVerification(id: Int) async throws -> PropertyDetail {
        try await client.post("properties/\(id)/request-verification", as: PropertyDetail.self)
    }

    // MARK: - Lifts and stairs

    struct ElevatorBody: Encodable {
        var name: String?
        var type: String?
        var capacity: Int?
        var max_occupancy: Int?
        var width: Double?
        var depth: Double?
        var height: Double?
        var door_width: Double?
        var accessible: String?
        var service: String?
        var passenger: String?
        var notes: String?

        init(from elevator: Elevator) {
            name = elevator.name
            type = elevator.type
            capacity = elevator.capacity
            max_occupancy = elevator.maxOccupancy
            width = elevator.width
            depth = elevator.depth
            height = elevator.height
            door_width = elevator.doorWidth
            accessible = elevator.accessible.rawValue
            service = elevator.service.rawValue
            passenger = elevator.passenger.rawValue
            notes = elevator.notes
        }

        init() {}
    }

    func addElevator(propertyID: Int) async throws -> Elevator {
        try await client.post("properties/\(propertyID)/elevators", body: ElevatorBody(), as: Elevator.self)
    }

    func updateElevator(propertyID: Int, elevator: Elevator) async throws -> Elevator {
        try await client.patch(
            "properties/\(propertyID)/elevators/\(elevator.id)",
            body: ElevatorBody(from: elevator),
            as: Elevator.self
        )
    }

    func deleteElevator(propertyID: Int, elevatorID: Int) async throws -> MessageResponse {
        try await client.delete("properties/\(propertyID)/elevators/\(elevatorID)", as: MessageResponse.self)
    }

    struct StaircaseBody: Encodable {
        var name: String?
        var location: String?
        var floors_served: Int?
        var width: Double?
        var classification: String?
        var emergency_exit: String?
        var notes: String?

        init(from staircase: Staircase) {
            name = staircase.name
            location = staircase.location
            floors_served = staircase.floorsServed
            width = staircase.width
            classification = staircase.classification
            emergency_exit = staircase.emergencyExit.rawValue
            notes = staircase.notes
        }

        init() {}
    }

    func addStaircase(propertyID: Int) async throws -> Staircase {
        try await client.post("properties/\(propertyID)/staircases", body: StaircaseBody(), as: Staircase.self)
    }

    func updateStaircase(propertyID: Int, staircase: Staircase) async throws -> Staircase {
        try await client.patch(
            "properties/\(propertyID)/staircases/\(staircase.id)",
            body: StaircaseBody(from: staircase),
            as: Staircase.self
        )
    }

    func deleteStaircase(propertyID: Int, staircaseID: Int) async throws -> MessageResponse {
        try await client.delete("properties/\(propertyID)/staircases/\(staircaseID)", as: MessageResponse.self)
    }

    // MARK: - Documents

    func uploadDocument(
        propertyID: Int,
        fileURL: URL,
        type: String,
        notes: String
    ) async throws -> PropertyDocument {
        try await client.upload(
            "properties/\(propertyID)/documents",
            fileURL: fileURL,
            fields: ["type": type, "notes": notes],
            as: PropertyDocument.self
        )
    }

    func deleteDocument(propertyID: Int, documentID: Int) async throws -> MessageResponse {
        try await client.delete("properties/\(propertyID)/documents/\(documentID)", as: MessageResponse.self)
    }

    func downloadDocument(_ document: PropertyDocument) async throws -> URL {
        try await client.download("documents/\(document.id)/download", suggestedName: document.name)
    }

    // MARK: - Change flags

    struct FlagBody: Encodable {
        let action: String
    }

    func resolveFlag(propertyID: Int, flagID: Int, confirm: Bool) async throws -> PropertyDetail {
        try await client.post(
            "properties/\(propertyID)/flags/\(flagID)/resolve",
            body: FlagBody(action: confirm ? "confirm" : "revert"),
            as: PropertyDetail.self
        )
    }

    // MARK: - Reports

    func report(filters: PropertyFilters, columns: [String]) async throws -> ReportPayload {
        var query = filters.queryItems
        query.append(URLQueryItem(name: "columns", value: columns.joined(separator: ",")))

        return try await client.get("reports", query: query, as: ReportPayload.self)
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case xlsx, csv, pdf

        var id: String { rawValue }

        var label: String {
            switch self {
            case .xlsx: return "Excel"
            case .csv: return "CSV"
            case .pdf: return "PDF"
            }
        }

        var systemImage: String {
            switch self {
            case .xlsx: return "tablecells"
            case .csv: return "doc.plaintext"
            case .pdf: return "doc.richtext"
            }
        }
    }

    func exportReport(
        format: ExportFormat,
        filters: PropertyFilters,
        columns: [String],
        entirePortfolio: Bool
    ) async throws -> URL {
        var query = entirePortfolio ? [URLQueryItem(name: "scope", value: "all")] : filters.queryItems
        query.append(URLQueryItem(name: "columns", value: columns.joined(separator: ",")))

        return try await client.download(
            "reports/export/\(format.rawValue)",
            query: query,
            suggestedName: "london-portfolio.\(format.rawValue)"
        )
    }

    // MARK: - Import

    func importPreview(fileURL: URL) async throws -> ImportParse {
        try await client.upload("import/preview", fileURL: fileURL, as: ImportParse.self)
    }

    struct RemapBody: Encodable {
        let rows: [[String: ReportCell]]
        let mapping: [String: String]
    }

    struct RemapResponse: Decodable {
        let preview: [ImportPreviewRow]
    }

    func importRemap(rows: [[String: ReportCell]], mapping: [String: String]) async throws -> [ImportPreviewRow] {
        try await client.post(
            "import/remap",
            body: RemapBody(rows: rows, mapping: mapping),
            as: RemapResponse.self
        ).preview
    }

    struct CommitBody: Encodable {
        let rows: [[String: ReportCell]]
        let mapping: [String: String]
        let fileName: String
    }

    func importCommit(
        rows: [[String: ReportCell]],
        mapping: [String: String],
        fileName: String
    ) async throws -> ImportResult {
        try await client.post(
            "import/commit",
            body: CommitBody(rows: rows, mapping: mapping, fileName: fileName),
            as: ImportResult.self
        )
    }

    func downloadSampleSpreadsheet() async throws -> URL {
        try await client.download(
            "import/sample",
            suggestedName: "legacy-property-spreadsheet.xlsx"
        )
    }

    // MARK: - Admin

    struct FieldsResponse: Decodable {
        let message: String?
        let fields: [FieldDefinition]
    }

    struct NewFieldBody: Encodable {
        let label: String
        let section: String
        let type: String
        let required: Bool
        let help: String?
        let unit: String?
        let optionList: [String]?
    }

    func createField(_ body: NewFieldBody) async throws -> FieldsResponse {
        try await client.post("field-definitions", body: body, as: FieldsResponse.self)
    }

    func deleteField(_ field: FieldDefinition) async throws -> FieldsResponse {
        guard let id = field.definitionId else {
            throw APIError.forbidden("Base fields cannot be removed.")
        }

        return try await client.delete("field-definitions/\(id)", as: FieldsResponse.self)
    }

    struct OptionsResponse: Decodable {
        let options: [String: [String]]
    }

    struct OptionBody: Encodable {
        let value: String
    }

    func addOption(list: String, value: String) async throws -> OptionsResponse {
        try await client.post("option-lists/\(list)", body: OptionBody(value: value), as: OptionsResponse.self)
    }

    func removeOption(list: String, value: String) async throws -> OptionsResponse {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value

        return try await client.delete("option-lists/\(list)/\(encoded)", as: OptionsResponse.self)
    }
}

// MARK: - Filters

/// The scope every screen shares: search text plus the five dropdown filters.
struct PropertyFilters: Equatable, Sendable {
    var query: String = ""
    var borough: String = ""
    var council: String = ""
    var region: String = ""
    var propertyType: String = ""
    var verification: String = ""

    var isActive: Bool {
        !query.isEmpty || !borough.isEmpty || !council.isEmpty
            || !region.isEmpty || !propertyType.isEmpty || !verification.isEmpty
    }

    /// Count of active filters, for the badge on the filter button.
    var activeCount: Int {
        [borough, council, region, propertyType, verification].filter { !$0.isEmpty }.count
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []

        func add(_ name: String, _ value: String) {
            guard !value.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: value))
        }

        add("q", query)
        add("borough", borough)
        add("council", council)
        add("region", region)
        add("propertyType", propertyType)
        add("verification", verification)

        return items
    }

    mutating func clear() {
        self = PropertyFilters()
    }

    /// Clears the dropdowns but keeps whatever the user has typed.
    mutating func clearDropdowns() {
        borough = ""
        council = ""
        region = ""
        propertyType = ""
        verification = ""
    }
}
