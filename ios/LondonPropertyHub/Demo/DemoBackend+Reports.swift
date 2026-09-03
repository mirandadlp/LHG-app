import Foundation

/// The dashboard and the report table, computed the way `ReportBuilder` does it
/// on the server: over the filtered, role-scoped set, so every figure on screen
/// matches the records the signed-in persona can actually open.
extension DemoBackend {

    // MARK: - Dashboard

    func dashboard(filters: PropertyFilters) -> DashboardPayload {
        let definitions = fields
        let visible = visibleProperties(filters: filters)

        var units = 0, singles = 0, doubles = 0, triples = 0, wcSc = 0
        var flats = 0, houses = 0, lifts = 0, staircases = 0
        var accessibleRooms = 0, verified = 0, completenessSum = 0
        var boroughs: [String: Int] = [:]
        var statuses: [String: Int] = [:]

        for property in visible {
            units += property.totalUnits
            singles += property.count("singles")
            doubles += property.count("doubles")
            triples += property.count("triples")
            wcSc += property.count("wcSc")
            flats += property.flatsTotal
            houses += property.housesTotal
            lifts += property.elevators.count
            staircases += property.staircases.count
            accessibleRooms += property.values["accessibleBedroomCount"]?.intValue ?? 0

            if property.verification == .verified { verified += 1 }

            let borough = property.values["borough"]?.stringValue ?? ""
            boroughs[borough.isEmpty ? "Unassigned" : borough, default: 0] += property.totalUnits
            statuses[property.verification.rawValue, default: 0] += 1
            completenessSum += property.completeness(fields: definitions)
        }

        let totals = DashboardPayload.Totals(
            properties: visible.count,
            units: units,
            singles: singles,
            doubles: doubles,
            triples: triples,
            wcSc: wcSc,
            flats: flats,
            houses: houses,
            lifts: lifts,
            staircases: staircases,
            accessibleRooms: accessibleRooms,
            verified: verified,
            awaiting: visible.count - verified,
            avgComplete: visible.isEmpty ? 0 : Int((Double(completenessSum) / Double(visible.count)).rounded())
        )

        // Under 80% complete, or sitting in a status that means work is
        // outstanding — the same test the server applies.
        let needsAttention = visible.filter { property in
            property.completeness(fields: definitions) < 80
                || [.overdue, .changesRequested, .notStarted].contains(property.verification)
        }

        return DashboardPayload(
            totals: totals,
            byBorough: boroughs
                .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
                .map { DashboardPayload.BoroughUnits(name: $0.key, units: $0.value) },
            byStatus: DemoRegistry.verificationStatuses.compactMap { name in
                statuses[name].map { DashboardPayload.StatusCount(name: name, value: $0) }
            },
            needsAttention: needsAttention.map { $0.summary(fields: definitions) },
            filterActive: filters.isActive
        )
    }

    // MARK: - Report table

    func report(filters: PropertyFilters, columns: [String]) -> ReportPayload {
        let visible = visibleProperties(filters: filters)
        let chosen = resolve(columns)
        let rows = visible.map { project(row(for: $0), to: chosen) }

        return ReportPayload(
            columns: chosen,
            availableColumns: DemoRegistry.allReportColumns,
            rows: rows,
            totals: totalsRow(rows, columns: chosen),
            propertyCount: visible.count,
            unitCount: visible.reduce(0) { $0 + $1.totalUnits },
            filterActive: filters.isActive
        )
    }

    /// A file of the report currently on screen, written to a temporary URL the
    /// share sheet can hand to another app — a real CSV, a real workbook, a real
    /// PDF, not a placeholder.
    func exportReport(
        format: PropertyAPI.ExportFormat,
        filters: PropertyFilters,
        columns: [String],
        entirePortfolio: Bool
    ) async throws -> URL {
        let scope = entirePortfolio ? PropertyFilters() : filters
        let payload = report(filters: scope, columns: columns)

        // Files get the raw figures, not the grouped strings the table shows:
        // "1,234" in a spreadsheet cell is text, and stops being summable.
        var table = [payload.columns]

        table += payload.rows.map { row in payload.columns.map { plain(row[$0]) } }
        table.append(payload.columns.map { plain(payload.totals[$0]) })

        switch format {
        case .csv:
            return try DemoFiles.writeCSV(table, named: "london-portfolio.csv")
        case .xlsx:
            return try DemoFiles.writeXLSX(table, sheetName: "Portfolio", named: "london-portfolio.xlsx")
        case .pdf:
            return try await DemoFiles.writePDF(
                table,
                title: "London Hotel Group — Property Portfolio",
                subtitle: "\(payload.propertyCount) properties · \(payload.unitCount) units"
                    + (payload.filterActive ? " · filtered" : ""),
                named: "london-portfolio.pdf"
            )
        }
    }

    private func plain(_ cell: ReportCell?) -> String {
        guard let cell else { return "" }

        switch cell {
        case .number(let value):
            return value == value.rounded() ? String(Int(value)) : String(value)
        case .text(let text):
            return text
        }
    }

    /// Every column for one property, before the caller's selection narrows it.
    private func row(for property: DemoProperty) -> [String: ReportCell] {
        let definitions = fields

        return [
            "Site": .text(property.siteName),
            "Address": .text(property.fullAddress),
            "Borough": .text(property.values["borough"]?.stringValue ?? ""),
            "Council": .text(property.values["council"]?.stringValue ?? ""),
            "Region": .text(property.values["region"]?.stringValue ?? ""),
            "Property type": .text(property.values["propertyType"]?.stringValue ?? ""),
            "Singles": .number(Double(property.count("singles"))),
            "Doubles": .number(Double(property.count("doubles"))),
            "Triples": .number(Double(property.count("triples"))),
            "WC SC units": .number(Double(property.count("wcSc"))),
            "Flats": .number(Double(property.flatsTotal)),
            "Houses": .number(Double(property.housesTotal)),
            "Total units": .number(Double(property.totalUnits)),
            "Elevators": .number(Double(property.elevators.count)),
            "Staircases": .number(Double(property.staircases.count)),
            "Accessible bedrooms": .number(Double(property.values["accessibleBedroomCount"]?.intValue ?? 0)),
            "Step-free entrance": .text(property.values["stepFree"]?.stringValue ?? ""),
            "Manager": .text(property.values["manager"]?.stringValue ?? ""),
            "Verification status": .text(property.verification.rawValue),
            "Completeness %": .number(Double(property.completeness(fields: definitions))),
            "Last updated": .text(property.lastUpdatedLabel ?? "—"),
        ]
    }

    private func resolve(_ columns: [String]) -> [String] {
        let chosen = DemoRegistry.allReportColumns.filter { columns.contains($0) }

        return chosen.isEmpty ? DemoRegistry.defaultReportColumns : chosen
    }

    private func project(_ row: [String: ReportCell], to columns: [String]) -> [String: ReportCell] {
        columns.reduce(into: [:]) { result, column in
            result[column] = row[column] ?? .text("")
        }
    }

    /// The company-total row from the original report table.
    private func totalsRow(_ rows: [[String: ReportCell]], columns: [String]) -> [String: ReportCell] {
        columns.reduce(into: [:]) { totals, column in
            if column == "Site" {
                totals[column] = .text("Company total")
                return
            }

            guard DemoRegistry.numericReportColumns.contains(column) else {
                totals[column] = .text("")
                return
            }

            totals[column] = .number(rows.reduce(0) { sum, row in
                if case .number(let value) = row[column] ?? .text("") { return sum + value }
                return sum
            })
        }
    }
}
