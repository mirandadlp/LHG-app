import Foundation
import Testing

@testable import LondonPropertyHub

/// The client's job is to decode whatever the API sends without losing meaning.
/// These cover the shapes that are easy to get subtly wrong.
struct FieldValueTests {

    private func decode(_ json: String) throws -> FieldValue {
        try JSONDecoder().decode(FieldValue.self, from: Data(json.utf8))
    }

    @Test("Null and empty string both read as empty")
    func emptyValues() throws {
        #expect(try decode("null").isEmpty)
        #expect(try decode("\"\"").isEmpty)
        #expect(try decode("\"Croydon\"").isEmpty == false)
    }

    @Test("A measurement keeps its value and unit")
    func measurement() throws {
        let value = try decode("{\"v\": 12.6, \"u\": \"m²\"}")

        #expect(value.doubleValue == 12.6)
        #expect(value.measurementUnit == "m²")
        #expect(value.stringValue == "12.6 m²")
    }

    @Test("A measurement with no magnitude is empty, not zero")
    func emptyMeasurement() throws {
        let value = try decode("{\"v\": null, \"u\": \"m²\"}")

        #expect(value.isEmpty)
        #expect(value.displayValue == "—")
    }

    @Test("Whole numbers display without a decimal tail")
    func wholeNumbers() throws {
        #expect(try decode("7").stringValue == "7")
        #expect(try decode("7.0").stringValue == "7")
        #expect(try decode("7.5").stringValue == "7.5")
    }

    @Test("Whole numbers encode as integers so the API stores 7, not 7.0")
    func encodesWholeNumbersAsIntegers() throws {
        let encoded = try JSONEncoder().encode(FieldValue.number(7))

        #expect(String(data: encoded, encoding: .utf8) == "7")
    }

    @Test("A measurement round-trips through encoding")
    func measurementRoundTrip() throws {
        let original = FieldValue.measurement(value: 13.75, unit: "ft²")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FieldValue.self, from: data)

        #expect(decoded == original)
    }

    @Test("Yes/No/N-A reads back as a tri-state")
    func triState() throws {
        #expect(try decode("\"Yes\"").triState == .yes)
        #expect(try decode("\"N/A\"").triState == .notApplicable)
        #expect(try decode("\"Croydon\"").triState == nil)
    }
}

struct VerificationStatusTests {

    @Test("Every status the server can send is understood")
    func knownStatuses() throws {
        for status in VerificationStatus.allCases {
            let json = Data("\"\(status.rawValue)\"".utf8)

            #expect(try JSONDecoder().decode(VerificationStatus.self, from: json) == status)
        }
    }

    @Test("An unknown status degrades instead of failing the whole response")
    func unknownStatus() throws {
        let json = Data("\"Escalated\"".utf8)

        #expect(try JSONDecoder().decode(VerificationStatus.self, from: json) == .notStarted)
    }
}

struct PropertyFiltersTests {

    @Test("An empty filter set produces no query items")
    func emptyFilters() {
        #expect(PropertyFilters().queryItems.isEmpty)
        #expect(PropertyFilters().isActive == false)
    }

    @Test("Only the filters that are set are sent")
    func partialFilters() {
        var filters = PropertyFilters()
        filters.borough = "Croydon"
        filters.query = "riverside"

        let names = filters.queryItems.map(\.name).sorted()

        #expect(names == ["borough", "q"])
        #expect(filters.isActive)
        #expect(filters.activeCount == 1) // The search text is not a dropdown.
    }

    @Test("Clearing dropdowns keeps what the user typed")
    func clearDropdowns() {
        var filters = PropertyFilters()
        filters.query = "greenwich"
        filters.borough = "Greenwich"
        filters.region = "London South"

        filters.clearDropdowns()

        #expect(filters.query == "greenwich")
        #expect(filters.borough.isEmpty)
        #expect(filters.activeCount == 0)
    }
}

struct ThemeTests {

    @Test("Completeness colour follows the same thresholds as the web app")
    func completenessThresholds() {
        #expect(Theme.completenessColor(100) == Theme.green)
        #expect(Theme.completenessColor(90) == Theme.green)
        #expect(Theme.completenessColor(89) == Theme.amber)
        #expect(Theme.completenessColor(70) == Theme.amber)
        #expect(Theme.completenessColor(69) == Theme.red)
        #expect(Theme.completenessColor(0) == Theme.red)
    }

    @Test("Counts are formatted British style")
    func counts() {
        #expect(1243.formattedCount == "1,243")
        #expect(0.formattedCount == "0")
    }
}
