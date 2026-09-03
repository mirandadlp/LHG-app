import Foundation

/// The portfolio the demo starts from: the same seven properties the server
/// seeder creates, in the same seven verification states, so the demo shows the
/// app the way a real deployment looks on day one.
///
/// Dates are relative to now rather than fixed, so the audit trail reads as
/// recent activity however long after this was written the demo is run.
enum DemoSeed {

    /// The three properties the demo property manager is named on. Everything
    /// else is invisible to that persona, which is the point — role scoping is
    /// something you should be able to *see* in the demo.
    private static let managerEmail = DemoPersona.manager.email

    static func portfolio() -> [DemoProperty] {
        [croydon(), lewisham(), newham(), greenwich(), ealing(), camden(), barking()]
    }

    // MARK: - 1 · Croydon Housing — In Progress, the manager's main record

    private static func croydon() -> DemoProperty {
        DemoProperty(
            id: 1,
            publicId: "d1000000-0000-4000-8000-000000000001",
            verification: .inProgress,
            submittedAt: nil,
            verifiedAt: nil,
            verificationDueOn: DemoFormat.daysAhead(12),
            values: values(
                text: [
                    "siteName": "Croydon Housing", "propertyName": "Croydon Housing",
                    "addressLine1": "142 London Road", "addressLine2": "Broad Green", "city": "Croydon",
                    "postcode": "CR0 2TB", "borough": "Croydon", "council": "Croydon Council",
                    "region": "London South", "propertyType": "Residential Housing",
                    "ownershipCompany": "London PropCo 3 Ltd", "managementCompany": "London Operations Ltd",
                    "manager": "Jane Smith", "managerEmail": managerEmail,
                    "managerPhone": "020 7946 0112", "operationalStatus": "Open", "openedDate": "2016-04-11",
                    "generalNotes": "Legacy records held in three separate spreadsheets prior to migration.",
                    "wheelchairEntrance": "Yes", "stepFree": "Yes", "accessibleBedrooms": "Yes",
                    "accessibleBathrooms": "Yes", "accessibleElevators": "Yes", "accessibleParking": "Yes",
                    "rampAccess": "Yes", "handrails": "Yes", "hearingAssistance": "No", "visualAssistance": "No",
                    "buildingType": "Converted Office",
                    "fireSafety": "L1 addressable alarm system. Sprinklers on floors 1–7. FRA completed in March.",
                ],
                numbers: [
                    "accessibleBedroomCount": 14, "floors": 7, "buildingCount": 2, "entrances": 3,
                    "emergencyExits": 6, "parkingSpaces": 42, "accessibleParkingSpaces": 4,
                    "constructionYear": 1974, "renovationYear": 2019, "cf_boilers": 4,
                ],
                measurements: [
                    "singleSize": 9.2, "doubleSize": 13.4, "tripleSize": 17.1,
                    "avgBedroom": 12.6, "minBedroom": 8.1, "maxBedroom": 22.4, "buildingArea": 8420,
                ]
            ),
            accommodation: counts([
                "singles": 105, "doubles": 72, "triples": 38, "wcSc": 47,
                "flat1": 33, "flat2": 24, "flat3": 12, "wcFlats": 4, "wcHouses": 4,
            ]),
            elevators: [
                lift(101, "Lift A — Main Core", capacity: 8, maxOccupancy: 8, width: 1.1, depth: 1.4,
                     height: 2.2, doorWidth: 0.9, notes: "Serves floors G–7.", position: 0),
                lift(102, "Lift B — Goods", type: "Service", capacity: 12, maxOccupancy: 12, width: 1.4,
                     depth: 2.1, height: 2.3, doorWidth: 1.1, accessible: .no, service: .yes,
                     passenger: .no, notes: "Housekeeping and deliveries only.", position: 1),
            ],
            staircases: [
                stair(101, "Stair 1", location: "North core", floorsServed: 8, width: 1.2,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
                stair(102, "Stair 2", location: "South core", floorsServed: 8, width: 1.1, position: 1),
            ],
            documents: [
                doc(101, "Croydon-Housing-Floorplans.pdf", "Floor Plan", daysAgo: 93,
                    by: "Jane Smith", notes: "Post-refurbishment set."),
                doc(102, "Croydon-Accessibility-Audit.pdf", "Accessibility Report", daysAgo: 112,
                    by: "Priya Raman"),
            ],
            history: [
                log(101, "Singles", "98", "105", by: "Jane Smith", daysAgo: 22,
                    reason: "Property manager verification", approval: "Pending"),
                log(102, "Number of accessible bedrooms", "12", "14", by: "Jane Smith", daysAgo: 22,
                    reason: "Two rooms converted last year", approval: "Pending"),
                log(103, "Most recent renovation year", "—", "2019", by: "Priya Raman", daysAgo: 35,
                    reason: "Migrated from legacy spreadsheet", approval: "Approved"),
            ],
            flags: [],
            updatedAt: DemoFormat.daysAgo(22)
        )
    }

    // MARK: - 2 · Lewisham Lodge Hotel — Verified

    private static func lewisham() -> DemoProperty {
        DemoProperty(
            id: 2,
            publicId: "d1000000-0000-4000-8000-000000000002",
            verification: .verified,
            submittedAt: nil,
            verifiedAt: DemoFormat.daysAgo(43),
            verificationDueOn: DemoFormat.daysAhead(47),
            values: values(
                text: [
                    "siteName": "Lewisham Lodge Hotel", "propertyName": "Lewisham Lodge",
                    "addressLine1": "8 Rennell Street", "city": "London", "postcode": "SE13 7HD",
                    "borough": "Lewisham", "council": "Lewisham Council", "region": "London South",
                    "propertyType": "Hotel", "ownershipCompany": "London PropCo 1 Ltd",
                    "managementCompany": "London Operations Ltd", "manager": "David Okafor",
                    "managerEmail": "david.okafor@londonhotelgroup.co.uk", "managerPhone": "020 7946 0187",
                    "operationalStatus": "Open", "openedDate": "2012-09-01",
                    "wheelchairEntrance": "Yes", "stepFree": "Yes", "accessibleBedrooms": "Yes",
                    "accessibleBathrooms": "Yes", "accessibleElevators": "Yes", "accessibleParking": "No",
                    "rampAccess": "Yes", "handrails": "Yes", "hearingAssistance": "Yes",
                    "visualAssistance": "Yes", "buildingType": "Purpose-built",
                    "fireSafety": "L2 system, annual certification current.",
                ],
                numbers: [
                    "accessibleBedroomCount": 9, "floors": 5, "buildingCount": 1, "entrances": 2,
                    "emergencyExits": 4, "parkingSpaces": 18, "accessibleParkingSpaces": 2,
                    "constructionYear": 2005, "renovationYear": 2022, "cf_boilers": 2,
                ],
                measurements: [
                    "singleSize": 11, "doubleSize": 15.5, "avgBedroom": 14,
                    "minBedroom": 10.2, "maxBedroom": 26, "buildingArea": 5100,
                ]
            ),
            accommodation: counts([
                "singles": 64, "doubles": 88, "triples": 21, "wcSc": 12, "flat1": 6, "flat2": 2,
            ]),
            elevators: [
                lift(201, "Guest Lift 1", capacity: 10, maxOccupancy: 10, width: 1.2, depth: 1.5,
                     doorWidth: 0.9, position: 0),
                lift(202, "Guest Lift 2", capacity: 10, maxOccupancy: 10, width: 1.2, depth: 1.5,
                     doorWidth: 0.9, position: 1),
                lift(203, "Service Lift", type: "Service", capacity: 14, accessible: .no,
                     service: .yes, passenger: .no, position: 2),
            ],
            staircases: [
                stair(201, "Main Stair", location: "Lobby", floorsServed: 6, width: 1.4,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
            ],
            documents: [
                doc(201, "Lewisham-Fire-Certificate.pdf", "Certificate", daysAgo: 176, by: "David Okafor"),
            ],
            history: [
                log(201, "Verification", "Submitted", "Verified", by: "Priya Raman", daysAgo: 43,
                    reason: "Approved after review", approval: "Approved"),
            ],
            flags: [],
            updatedAt: DemoFormat.daysAgo(43)
        )
    }

    // MARK: - 3 · Newham Riverside House — Submitted, with an open flag

    private static func newham() -> DemoProperty {
        DemoProperty(
            id: 3,
            publicId: "d1000000-0000-4000-8000-000000000003",
            verification: .submitted,
            submittedAt: DemoFormat.daysAgo(3),
            verifiedAt: nil,
            verificationDueOn: DemoFormat.daysAhead(4),
            values: values(
                text: [
                    "siteName": "Newham Riverside House", "propertyName": "Riverside House",
                    "addressLine1": "24 Cundy Road", "city": "London", "postcode": "E16 3DJ",
                    "borough": "Newham", "council": "Newham Council", "region": "London East",
                    "propertyType": "Temporary Accommodation", "ownershipCompany": "London PropCo 2 Ltd",
                    "managementCompany": "London Operations Ltd", "manager": "Aisha Khan",
                    "managerEmail": "aisha.khan@londonhotelgroup.co.uk", "managerPhone": "020 7946 0233",
                    "operationalStatus": "Open", "openedDate": "2018-02-19",
                    "wheelchairEntrance": "Yes", "stepFree": "No", "accessibleBedrooms": "Yes",
                    "accessibleBathrooms": "Yes", "accessibleElevators": "Yes", "accessibleParking": "No",
                    "rampAccess": "Yes", "handrails": "Yes", "hearingAssistance": "No",
                    "buildingType": "Converted Office",
                ],
                numbers: [
                    "accessibleBedroomCount": 6, "floors": 6, "buildingCount": 1, "entrances": 2,
                    "emergencyExits": 4, "parkingSpaces": 12, "accessibleParkingSpaces": 1,
                    "constructionYear": 1988,
                ],
                measurements: ["singleSize": 8.6, "doubleSize": 12.9, "avgBedroom": 11.4]
            ),
            accommodation: counts([
                "singles": 78, "doubles": 54, "triples": 44, "wcSc": 30,
                "flat1": 18, "flat2": 22, "flat3": 9, "house3": 3,
            ]),
            elevators: [
                lift(301, "Lift 1", capacity: 8, position: 0),
                lift(302, "Lift 2", type: "Service", capacity: 10, accessible: .no,
                     service: .yes, passenger: .no, position: 1),
            ],
            staircases: [
                stair(301, "East Stair", location: "East wing", floorsServed: 7, width: 1.1,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
            ],
            documents: [],
            history: [
                log(301, "Verification", "In Progress", "Submitted", by: "Aisha Khan", daysAgo: 3,
                    reason: "Submitted for review by property manager", approval: "Approved"),
                log(302, "Triples", "28", "44", by: "Aisha Khan", daysAgo: 24,
                    reason: "Reconfiguration completed in July", approval: "Pending"),
            ],
            // A 28 → 44 movement is a large change: it needs confirming before
            // anyone trusts it, which is what the flag banner is for.
            flags: [
                ChangeFlag(id: 301, key: "triples", label: "Triples", prev: 28, next: 44,
                           resolution: "Pending", raisedAt: DemoFormat.iso(DemoFormat.daysAgo(24))),
            ],
            updatedAt: DemoFormat.daysAgo(3)
        )
    }

    // MARK: - 4 · Greenwich Court Apartments — Verified, the most complete record

    private static func greenwich() -> DemoProperty {
        DemoProperty(
            id: 4,
            publicId: "d1000000-0000-4000-8000-000000000004",
            verification: .verified,
            submittedAt: nil,
            verifiedAt: DemoFormat.daysAgo(20),
            verificationDueOn: DemoFormat.daysAhead(70),
            values: values(
                text: [
                    "siteName": "Greenwich Court Apartments", "propertyName": "Greenwich Court",
                    "addressLine1": "3 Norman Road", "city": "London", "postcode": "SE10 9QX",
                    "borough": "Greenwich", "council": "Royal Borough of Greenwich", "region": "London South",
                    "propertyType": "Serviced Apartments", "ownershipCompany": "London PropCo 1 Ltd",
                    "managementCompany": "London Operations Ltd", "manager": "Tom Reilly",
                    "managerEmail": "tom.reilly@londonhotelgroup.co.uk", "managerPhone": "020 7946 0301",
                    "operationalStatus": "Open", "openedDate": "2021-06-30",
                    "wheelchairEntrance": "Yes", "stepFree": "Yes", "accessibleBedrooms": "Yes",
                    "accessibleBathrooms": "Yes", "accessibleElevators": "Yes", "accessibleParking": "Yes",
                    "rampAccess": "Yes", "handrails": "Yes", "hearingAssistance": "Yes",
                    "visualAssistance": "Yes", "buildingType": "New Build",
                    "fireSafety": "Sprinklered throughout. L1 system.",
                    "dimensionNotes": "Internal floor area, excluding en-suite and balcony.",
                ],
                numbers: [
                    "accessibleBedroomCount": 11, "floors": 9, "buildingCount": 1, "entrances": 2,
                    "emergencyExits": 5, "parkingSpaces": 60, "accessibleParkingSpaces": 6,
                    "constructionYear": 2020, "renovationYear": 2020, "cf_boilers": 6,
                ],
                measurements: [
                    "singleSize": 12, "doubleSize": 16.8, "avgBedroom": 15.2,
                    "minBedroom": 11, "maxBedroom": 24, "buildingArea": 11200,
                ]
            ),
            accommodation: counts([
                "flat1": 64, "flat2": 48, "flat3": 18, "wcFlats": 6, "doubles": 12,
            ]),
            elevators: [
                lift(401, "Core A Lift 1", capacity: 13, position: 0),
                lift(402, "Core A Lift 2", capacity: 13, position: 1),
                lift(403, "Core B Lift", capacity: 8, position: 2),
                lift(404, "Service Lift", type: "Service", capacity: 16, accessible: .no,
                     service: .yes, passenger: .no, position: 3),
            ],
            staircases: [
                stair(401, "Core A Stair", location: "Core A", floorsServed: 10, width: 1.3,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
                stair(402, "Core B Stair", location: "Core B", floorsServed: 10, width: 1.3,
                      classification: "Emergency", emergencyExit: .yes, position: 1),
            ],
            documents: [
                doc(401, "Greenwich-Property-Survey.pdf", "Property Survey", daysAgo: 237, by: "Tom Reilly"),
            ],
            history: [],
            flags: [],
            updatedAt: DemoFormat.daysAgo(20)
        )
    }

    // MARK: - 5 · Ealing Park Hostel — sent back for changes

    private static func ealing() -> DemoProperty {
        DemoProperty(
            id: 5,
            publicId: "d1000000-0000-4000-8000-000000000005",
            verification: .changesRequested,
            submittedAt: nil,
            verifiedAt: nil,
            verificationDueOn: DemoFormat.daysAhead(6),
            values: values(
                text: [
                    "siteName": "Ealing Park Hostel", "propertyName": "Ealing Park",
                    "addressLine1": "77 Uxbridge Road", "city": "London", "postcode": "W5 5SL",
                    "borough": "Ealing", "council": "Ealing Council", "region": "London West",
                    "propertyType": "Hostel", "ownershipCompany": "London PropCo 3 Ltd",
                    "managementCompany": "London Operations Ltd", "manager": "Jane Smith",
                    "managerEmail": managerEmail, "operationalStatus": "Open", "openedDate": "2019-11-05",
                    "wheelchairEntrance": "No", "stepFree": "No", "accessibleBedrooms": "No",
                    "accessibleBathrooms": "No", "accessibleElevators": "N/A", "rampAccess": "No",
                    "handrails": "Yes", "buildingType": "Victorian Terrace",
                ],
                numbers: [
                    "accessibleBedroomCount": 0, "floors": 4, "buildingCount": 1,
                    "entrances": 1, "emergencyExits": 2, "constructionYear": 1901,
                ],
                measurements: ["avgBedroom": 10.1]
            ),
            accommodation: counts(["singles": 40, "doubles": 36, "triples": 26, "wcSc": 8]),
            elevators: [],
            staircases: [
                stair(501, "Main Stair", location: "Central", floorsServed: 5, width: 0.9,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
            ],
            documents: [],
            history: [
                log(501, "Verification", "Submitted", "Changes Requested", by: "Priya Raman", daysAgo: 29,
                    reason: "Room dimensions and fire safety information missing", approval: "Approved"),
            ],
            flags: [],
            updatedAt: DemoFormat.daysAgo(29)
        )
    }

    // MARK: - 6 · Camden Row Residences — barely started

    private static func camden() -> DemoProperty {
        DemoProperty(
            id: 6,
            publicId: "d1000000-0000-4000-8000-000000000006",
            verification: .notStarted,
            submittedAt: nil,
            verifiedAt: nil,
            verificationDueOn: nil,
            values: values(
                text: [
                    "siteName": "Camden Row Residences", "propertyName": "Camden Row",
                    "addressLine1": "12 Bayham Street", "city": "London", "postcode": "NW1 0EY",
                    "borough": "Camden", "council": "Camden Council", "region": "London North",
                    "propertyType": "Mixed Use", "manager": "Unassigned", "operationalStatus": "Open",
                ]
            ),
            accommodation: counts(["singles": 22, "doubles": 18, "flat1": 9, "flat2": 6]),
            elevators: [],
            staircases: [],
            documents: [],
            history: [],
            flags: [],
            updatedAt: DemoFormat.daysAgo(64)
        )
    }

    // MARK: - 7 · Barking Gateway House — overdue

    private static func barking() -> DemoProperty {
        DemoProperty(
            id: 7,
            publicId: "d1000000-0000-4000-8000-000000000007",
            verification: .overdue,
            submittedAt: nil,
            verifiedAt: nil,
            verificationDueOn: DemoFormat.daysAgo(9),
            values: values(
                text: [
                    "siteName": "Barking Gateway House", "propertyName": "Gateway House",
                    "addressLine1": "5 Abbey Road", "city": "Barking", "postcode": "IG11 7BT",
                    "borough": "Barking & Dagenham", "council": "Barking & Dagenham Council",
                    "region": "London East", "propertyType": "Temporary Accommodation",
                    "ownershipCompany": "London PropCo 2 Ltd", "manager": "Jane Smith",
                    "managerEmail": managerEmail, "operationalStatus": "Partially Open",
                    "wheelchairEntrance": "Yes", "stepFree": "Yes", "accessibleBedrooms": "Yes",
                ],
                numbers: [
                    "floors": 5, "emergencyExits": 3, "buildingCount": 1, "accessibleBedroomCount": 4,
                ]
            ),
            accommodation: counts([
                "singles": 55, "doubles": 31, "triples": 12, "wcSc": 20,
                "flat2": 14, "house3": 6, "house4": 2,
            ]),
            elevators: [lift(701, "Lift 1", capacity: 8, position: 0)],
            staircases: [
                stair(701, "Stair A", location: "North", floorsServed: 6, width: 1.1,
                      classification: "Emergency", emergencyExit: .yes, position: 0),
            ],
            documents: [],
            history: [
                log(701, "Verification", "In Progress", "Overdue", by: "Priya Raman", daysAgo: 9,
                    reason: "Verification round passed its due date", approval: "Approved"),
            ],
            flags: [],
            updatedAt: DemoFormat.daysAgo(9)
        )
    }

    // MARK: - Builders

    private static func values(
        text: [String: String] = [:],
        numbers: [String: Int] = [:],
        measurements: [String: Double] = [:]
    ) -> [String: FieldValue] {
        var bag: [String: FieldValue] = [:]

        for (key, value) in text { bag[key] = .text(value) }
        for (key, value) in numbers { bag[key] = .number(Double(value)) }
        for (key, value) in measurements { bag[key] = .measurement(value: value, unit: "m²") }

        return bag
    }

    /// Every type is present on every record, blank where nothing was counted —
    /// `updateValue` rather than a subscript, which would read a nil as "remove
    /// this key" and quietly drop it.
    private static func counts(_ entries: [String: Int]) -> [String: Int?] {
        var bag: [String: Int?] = [:]

        for key in DemoRegistry.accommodationKeys {
            bag.updateValue(entries[key], forKey: key)
        }

        return bag
    }

    private static func lift(
        _ id: Int,
        _ name: String,
        type: String = "Passenger",
        capacity: Int? = nil,
        maxOccupancy: Int? = nil,
        width: Double? = nil,
        depth: Double? = nil,
        height: Double? = nil,
        doorWidth: Double? = nil,
        accessible: TriState = .yes,
        service: TriState = .no,
        passenger: TriState = .yes,
        notes: String = "",
        position: Int
    ) -> Elevator {
        Elevator(
            id: id, name: name, type: type, capacity: capacity, maxOccupancy: maxOccupancy,
            width: width, depth: depth, height: height, doorWidth: doorWidth,
            accessible: accessible, service: service, passenger: passenger,
            notes: notes, position: position
        )
    }

    private static func stair(
        _ id: Int,
        _ name: String,
        location: String = "",
        floorsServed: Int? = nil,
        width: Double? = nil,
        classification: String = "Standard",
        emergencyExit: TriState = .no,
        notes: String = "",
        position: Int
    ) -> Staircase {
        Staircase(
            id: id, name: name, location: location, floorsServed: floorsServed, width: width,
            classification: classification, emergencyExit: emergencyExit, notes: notes, position: position
        )
    }

    private static func doc(
        _ id: Int,
        _ name: String,
        _ type: String,
        daysAgo: Int,
        by: String,
        notes: String = ""
    ) -> PropertyDocument {
        PropertyDocument(
            id: id,
            name: name,
            type: type,
            date: DemoFormat.day(DemoFormat.daysAgo(daysAgo)),
            by: by,
            notes: notes,
            sizeBytes: nil,
            mimeType: "application/pdf",
            downloadUrl: "demo://documents/\(id)"
        )
    }

    private static func log(
        _ id: Int,
        _ field: String,
        _ prev: String,
        _ next: String,
        by: String,
        daysAgo: Int,
        reason: String,
        approval: String
    ) -> ChangeLogEntry {
        ChangeLogEntry(
            id: id,
            field: field,
            prev: prev,
            next: next,
            by: by,
            date: DemoFormat.stamp(DemoFormat.daysAgo(daysAgo)),
            reason: reason,
            approval: approval
        )
    }
}
