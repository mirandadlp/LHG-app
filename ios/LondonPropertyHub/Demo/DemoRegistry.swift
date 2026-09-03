import Foundation

/// The server's `FieldRegistry`, `AccommodationRegistry`, `OptionListSeeder` and
/// `ReportBuilder` column lists, mirrored in Swift so the demo can answer
/// `/bootstrap` without a server.
///
/// This is the one place the mirror exists. If a base field is added on the
/// server, adding it here keeps the demo honest; nothing else in the app
/// hardcodes the registry.
enum DemoRegistry {

    // MARK: - Sections

    static let sections: [BootstrapPayload.SectionDescriptor] = [
        .init(id: "general", label: "General information"),
        .init(id: "dimensions", label: "Room dimensions"),
        .init(id: "accessibility", label: "Accessibility"),
        .init(id: "building", label: "Building"),
    ]

    // MARK: - Base fields

    static let baseFields: [FieldDefinition] = [
        /* -------------------- General information -------------------- */
        f("siteName", .general, "Site name", .text, required: true, help: "The name used on internal reporting."),
        f("propertyName", .general, "Property name", .text, required: true),
        f("addressLine1", .general, "Address line 1", .text, required: true),
        f("addressLine2", .general, "Address line 2", .text),
        f("city", .general, "City / town", .text, required: true),
        f("postcode", .general, "Postal code", .postcode, required: true, help: "UK format, e.g. CR0 2RF."),
        f("borough", .general, "Borough", .select, required: true, optionListKey: "boroughs"),
        f("council", .general, "Council", .select, required: true, optionListKey: "councils"),
        f("region", .general, "Region", .select, required: true, optionListKey: "regions"),
        f("propertyType", .general, "Property type", .select, required: true, optionListKey: "propertyTypes"),
        f("ownershipCompany", .general, "Ownership company", .text),
        f("managementCompany", .general, "Management company", .text),
        f("manager", .general, "General manager / property manager", .text, required: true),
        f("managerEmail", .general, "Property manager email", .email, required: true),
        f("managerPhone", .general, "Property manager phone", .text),
        f("operationalStatus", .general, "Operational status", .select, required: true, optionListKey: "operationalStatuses"),
        f("openedDate", .general, "Date property opened", .date),
        f("generalNotes", .general, "Notes", .notes),

        /* -------------------- Room dimensions -------------------- */
        f("singleSize", .dimensions, "Standard single room size", .measurement),
        f("doubleSize", .dimensions, "Standard double room size", .measurement),
        f("tripleSize", .dimensions, "Standard triple room size", .measurement),
        f("avgBedroom", .dimensions, "Average bedroom size", .measurement),
        f("minBedroom", .dimensions, "Minimum bedroom size", .measurement),
        f("maxBedroom", .dimensions, "Maximum bedroom size", .measurement),
        f("dimensionNotes", .dimensions, "Measurement notes", .notes,
          help: "Note how rooms were measured, e.g. internal floor area excluding en-suite."),

        /* -------------------- Accessibility -------------------- */
        f("wheelchairEntrance", .accessibility, "Wheelchair accessible entrance", .yesno, required: true),
        f("stepFree", .accessibility, "Step-free entrance", .yesno, required: true),
        f("accessibleBedrooms", .accessibility, "Accessible bedrooms", .yesno),
        f("accessibleBedroomCount", .accessibility, "Number of accessible bedrooms", .number),
        f("accessibleBathrooms", .accessibility, "Accessible bathrooms", .yesno),
        f("accessibleElevators", .accessibility, "Accessible elevators", .yesno),
        f("accessibleParking", .accessibility, "Accessible parking", .yesno),
        f("rampAccess", .accessibility, "Ramp access", .yesno),
        f("handrails", .accessibility, "Handrails", .yesno),
        f("hearingAssistance", .accessibility, "Hearing assistance", .yesno),
        f("visualAssistance", .accessibility, "Visual assistance features", .yesno),
        f("otherAccessibility", .accessibility, "Other accessibility features", .text),
        f("accessibilityNotes", .accessibility, "Accessibility notes", .notes),

        /* -------------------- Building -------------------- */
        f("floors", .building, "Number of floors", .number, required: true),
        f("buildingArea", .building, "Total building area", .measurement),
        f("buildingCount", .building, "Number of buildings on site", .number),
        f("entrances", .building, "Number of entrances", .number),
        f("emergencyExits", .building, "Number of emergency exits", .number, required: true),
        f("parkingSpaces", .building, "Number of parking spaces", .number),
        f("accessibleParkingSpaces", .building, "Number of accessible parking spaces", .number),
        f("fireSafety", .building, "Fire safety information", .notes,
          help: "Alarm system, sprinklers, last fire risk assessment date."),
        f("buildingType", .building, "Building type", .select, optionListKey: "buildingTypes"),
        f("constructionYear", .building, "Construction year", .number),
        f("renovationYear", .building, "Most recent renovation year", .number),
        f("buildingNotes", .building, "Notes", .notes),
    ]

    /// The custom field the prototype shipped with, so the Fields screen opens
    /// on something real rather than an empty list.
    static let seededCustomFields: [FieldDefinition] = [
        FieldDefinition(
            definitionId: 1,
            key: "cf_boilers",
            section: .building,
            label: "Number of boilers",
            type: .number,
            required: false,
            help: "Added by Corporate Admin, July 2026.",
            unit: nil,
            optionListKey: nil,
            optionList: nil,
            custom: true
        )
    ]

    // MARK: - Accommodation

    static let accommodationGroups = ["Rooms", "Flats", "Houses", "Other"]

    static let accommodationTypes: [AccommodationType] = [
        .init(key: "singles", label: "Singles", group: "Rooms"),
        .init(key: "doubles", label: "Doubles", group: "Rooms"),
        .init(key: "triples", label: "Triples", group: "Rooms"),
        .init(key: "wcSc", label: "Water Closet SC Units", group: "Rooms"),
        .init(key: "flat1", label: "1 Bedroom Flats", group: "Flats"),
        .init(key: "flat2", label: "2 Bedroom Flats", group: "Flats"),
        .init(key: "flat3", label: "3 Bedroom Flats", group: "Flats"),
        .init(key: "wcFlats", label: "WC Flats", group: "Flats"),
        .init(key: "house2", label: "2 Bedroom Houses", group: "Houses"),
        .init(key: "house3", label: "3 Bedroom Houses", group: "Houses"),
        .init(key: "house4", label: "4 Bedroom Houses", group: "Houses"),
        .init(key: "house5", label: "5 Bedroom Houses", group: "Houses"),
        .init(key: "wcHouses", label: "WC Houses", group: "Houses"),
        .init(key: "other", label: "Other Accommodation Type", group: "Other"),
    ]

    static let accommodationKeys = accommodationTypes.map(\.key)
    static let flatKeys = ["flat1", "flat2", "flat3", "wcFlats"]
    static let houseKeys = ["house2", "house3", "house4", "house5", "wcHouses"]

    static func accommodationLabel(_ key: String) -> String {
        accommodationTypes.first { $0.key == key }?.label ?? key
    }

    /// A change is "large" when a count moves by at least 10 units *and* by at
    /// least half of its previous value. Growth from zero is never flagged.
    static func isLargeChange(previous: Int, next: Int) -> Bool {
        guard previous > 0 else { return false }

        let delta = abs(next - previous)

        return delta >= 10 && Double(delta) / Double(previous) >= 0.5
    }

    // MARK: - Controlled lists

    static let optionLists: [String: [String]] = [
        "boroughs": [
            "Croydon", "Lewisham", "Newham", "Greenwich",
            "Ealing", "Camden", "Barking & Dagenham",
        ],
        "councils": [
            "Croydon Council", "Lewisham Council", "Newham Council",
            "Royal Borough of Greenwich", "Ealing Council", "Camden Council",
            "Barking & Dagenham Council",
        ],
        "regions": ["London South", "London East", "London North", "London West"],
        "propertyTypes": [
            "Hotel", "Hostel", "Temporary Accommodation",
            "Serviced Apartments", "Residential Housing", "Mixed Use",
        ],
        "operationalStatuses": ["Open", "Partially Open", "Closed for Refurbishment", "Pre-Opening"],
        "buildingTypes": [
            "Purpose-built", "Converted Office", "Converted Residential",
            "Victorian Terrace", "New Build",
        ],
        "elevatorTypes": ["Passenger", "Service", "Goods", "Platform Lift"],
        "documentTypes": [
            "Floor Plan", "Property Survey", "Building Specification",
            "Accessibility Report", "Safety Documentation", "Legacy Spreadsheet",
            "Photograph", "Certificate",
        ],
    ]

    static let measurementUnits = ["m²", "ft²", "m", "ft"]

    static let verificationStatuses = VerificationStatus.allCases.map(\.rawValue)

    // MARK: - Report columns

    static let allReportColumns = [
        "Site", "Address", "Borough", "Council", "Region", "Property type",
        "Singles", "Doubles", "Triples", "WC SC units", "Flats", "Houses",
        "Total units", "Elevators", "Staircases", "Accessible bedrooms",
        "Step-free entrance", "Manager", "Verification status",
        "Completeness %", "Last updated",
    ]

    static let defaultReportColumns = [
        "Site", "Address", "Borough", "Council", "Singles", "Doubles", "Triples",
        "Flats", "Houses", "Total units", "Elevators", "Verification status", "Last updated",
    ]

    static let numericReportColumns: Set<String> = [
        "Singles", "Doubles", "Triples", "WC SC units", "Flats", "Houses",
        "Total units", "Elevators", "Staircases", "Accessible bedrooms",
    ]

    // MARK: - Construction

    private static func f(
        _ key: String,
        _ section: FieldSection,
        _ label: String,
        _ type: FieldType,
        required: Bool = false,
        help: String? = nil,
        optionListKey: String? = nil
    ) -> FieldDefinition {
        FieldDefinition(
            definitionId: nil,
            key: key,
            section: section,
            label: label,
            type: type,
            required: required,
            help: help,
            unit: nil,
            optionListKey: optionListKey,
            optionList: nil,
            custom: false
        )
    }
}
