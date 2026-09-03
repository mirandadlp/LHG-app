import Foundation

/// The legacy-spreadsheet import, end to end.
///
/// Columns are matched to fields by name, the preview shows exactly what would
/// be created — duplicates and all — and nothing is written until it comes back
/// confirmed. That is the whole point of the feature, so the demo runs it for
/// real against a file the tester actually picks rather than replaying a canned
/// result.
extension DemoBackend {

    /// Headers can only land on general fields and accommodation counts.
    var importTargets: [ImportTarget] {
        let general = DemoRegistry.baseFields
            .filter { $0.section == .general }
            .map { ImportTarget(id: $0.key, label: $0.label) }

        let accommodation = DemoRegistry.accommodationTypes.map {
            ImportTarget(id: "accom:\($0.key)", label: "Accommodation — \($0.label)")
        }

        return general + accommodation
    }

    func importPreview(fileURL: URL) throws -> ImportParse {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can import a spreadsheet.")
        }

        let needsScope = fileURL.startAccessingSecurityScopedResource()

        defer { if needsScope { fileURL.stopAccessingSecurityScopedResource() } }

        guard ["csv", "txt", "tsv"].contains(fileURL.pathExtension.lowercased()) else {
            throw APIError.validation(
                message: "Demo mode reads CSV files. Download the sample spreadsheet below to try the import.",
                fields: [:]
            )
        }

        guard
            let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else {
            throw APIError.unknown("That file could not be read.")
        }

        // A CSV written for Excel starts with a byte-order mark, which would
        // otherwise become part of the first column's name.
        let grid = CSV.parse(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)

        guard var headers = grid.first else {
            throw APIError.validation(message: "That file has no rows in it.", fields: [:])
        }

        // Drop trailing unnamed columns produced by stray formatting.
        while let last = headers.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            headers.removeLast()
        }

        headers = headers.map { $0.trimmingCharacters(in: .whitespaces) }

        let rows: [[String: ReportCell]] = grid.dropFirst().compactMap { line in
            var row: [String: ReportCell] = [:]
            var hasContent = false

            for (index, header) in headers.enumerated() {
                let value = index < line.count ? line[index].trimmingCharacters(in: .whitespaces) : ""

                row[header] = Double(value).map(ReportCell.number) ?? .text(value)

                if !value.isEmpty { hasContent = true }
            }

            return hasContent ? row : nil
        }

        let mapping = guessMapping(headers)

        return ImportParse(
            fileName: fileURL.lastPathComponent,
            headers: headers,
            rows: rows,
            mapping: mapping,
            targets: importTargets,
            preview: preview(rows: rows, mapping: mapping)
        )
    }

    func importRemap(rows: [[String: ReportCell]], mapping: [String: String]) -> [ImportPreviewRow] {
        preview(rows: rows, mapping: mapping)
    }

    func importCommit(
        rows: [[String: ReportCell]],
        mapping: [String: String],
        fileName: String
    ) throws -> ImportResult {
        guard persona.role == .admin else {
            throw APIError.forbidden("Only a corporate administrator can import a spreadsheet.")
        }

        let entries = preview(rows: rows, mapping: mapping)
        let importable = entries.filter(\.importable)

        guard !importable.isEmpty else {
            throw APIError.validation(
                message: "Nothing in this file can be imported. Every row is either a duplicate or has no site name.",
                fields: [:]
            )
        }

        let source = fileName.isEmpty ? "a legacy spreadsheet" : fileName
        var created: [PropertySummary] = []

        for row in importable {
            var values = row.values

            if (values["operationalStatus"] ?? .empty).isEmpty {
                values["operationalStatus"] = .text("Open")
            }

            let detail = try createProperty(values: values, validate: false)

            if !row.accommodation.isEmpty {
                _ = try updateAccommodation(
                    id: detail.id,
                    counts: row.accommodation,
                    reason: "Imported from \(source)"
                )
            }

            let summary = try markImported(id: detail.id)

            created.append(summary)
        }

        return ImportResult(
            message: "\(created.count) \(created.count == 1 ? "property" : "properties") imported.",
            imported: created,
            skipped: entries.count - importable.count
        )
    }

    /// A sample legacy file so the flow can be tried before it matters. The live
    /// API sends a workbook; the demo sends the CSV equivalent, which the
    /// importer above then reads for real.
    func sampleSpreadsheet() throws -> URL {
        try DemoFiles.writeCSV(
            [
                ["Site Name", "Address Line 1", "City", "Postal Code", "Borough", "Council",
                 "Region", "Property Type", "General manager / property manager",
                 "Singles", "Doubles", "Triples", "1 Bedroom Flats"],
                ["Hackney Wick House", "18 Wallis Road", "London", "E9 5LN", "Newham",
                 "Newham Council", "London East", "Temporary Accommodation", "Leah Turner",
                 "44", "26", "8", "12"],
                ["Croydon Housing", "142 London Road", "Croydon", "CR0 2TB", "Croydon",
                 "Croydon Council", "London South", "Residential Housing", "Jane Smith",
                 "105", "72", "38", "0"],
                ["Southwark Bridge Rooms", "4 Sumner Street", "London", "SE1 9JA", "Lewisham",
                 "Lewisham Council", "London South", "Hotel", "",
                 "31", "40", "0", "0"],
            ],
            named: "legacy-property-spreadsheet.csv"
        )
    }

    // MARK: - Mapping

    /// "Site Name", "site_name" and "SITENAME" all land on siteName; anything
    /// unrecognised is left for a human to decide.
    private func guessMapping(_ headers: [String]) -> [String: String] {
        let targets = importTargets
        var mapping: [String: String] = [:]

        for header in headers {
            let normalised = normalise(header)
            mapping[header] = ""

            guard !normalised.isEmpty else { continue }

            if let exact = targets.first(where: { normalise($0.label) == normalised }) {
                mapping[header] = exact.id
                continue
            }

            // Longest label first, so "3 Bedroom Flats" beats "Flats".
            let candidates = targets.sorted { $0.label.count > $1.label.count }

            if let loose = candidates.first(where: { target in
                let label = normalise(target.label)

                return !label.isEmpty && (label.contains(normalised) || normalised.contains(label))
            }) {
                mapping[header] = loose.id
            }
        }

        return mapping
    }

    private func normalise(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Preview

    /// Every row, carrying the problems that would stop it importing.
    private func preview(rows: [[String: ReportCell]], mapping: [String: String]) -> [ImportPreviewRow] {
        let existing = existingSiteNames
        let requiredGeneral = DemoRegistry.baseFields.filter { $0.required && $0.section == .general }

        var seenInFile: Set<String> = []
        var entries: [ImportPreviewRow] = []

        for (index, row) in rows.enumerated() {
            var values: [String: FieldValue] = [:]
            var accommodation: [String: Int?] = [:]

            for (header, target) in mapping {
                guard !target.isEmpty, let cell = row[header] else { continue }

                // `ReportCell.display` groups thousands for the screen, which
                // is exactly wrong for reading a figure back out of a file.
                let value: FieldValue

                switch cell {
                case .number(let number): value = .number(number)
                case .text(let text): value = text.isEmpty ? .empty : .text(text)
                }

                if target.hasPrefix("accom:") {
                    let key = String(target.dropFirst("accom:".count))
                    let count: Int? = value.doubleValue.map { max(0, Int($0)) }

                    accommodation.updateValue(count, forKey: key)

                    continue
                }

                guard !value.isEmpty else { continue }

                values[target] = value
            }

            let siteName = values["siteName"]?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            let key = siteName.lowercased()

            let duplicateInSystem = !siteName.isEmpty && existing.contains(key)
            let duplicateInFile = !siteName.isEmpty && seenInFile.contains(key)

            if !siteName.isEmpty { seenInFile.insert(key) }

            let missing = requiredGeneral
                .filter { (values[$0.key] ?? .empty).isEmpty }
                .map(\.label)

            entries.append(
                ImportPreviewRow(
                    index: index,
                    values: values,
                    accommodation: accommodation,
                    totalUnits: accommodation.values.reduce(0) { $0 + ($1 ?? 0) },
                    duplicate: duplicateInSystem || duplicateInFile,
                    duplicateReason: duplicateInSystem
                        ? "Already in the system — will be skipped"
                        : (duplicateInFile ? "Repeated earlier in this file — will be skipped" : nil),
                    missingRequired: missing,
                    importable: !siteName.isEmpty && !duplicateInSystem && !duplicateInFile
                )
            )
        }

        return entries
    }
}

// MARK: - CSV

/// A CSV reader that handles the three things a legacy export actually does:
/// quoted fields, embedded commas and doubled quotes.
enum CSV {

    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.startIndex

        func endField() {
            row.append(field)
            field = ""
        }

        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        while iterator < text.endIndex {
            let character = text[iterator]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: iterator)

                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        iterator = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    endField()
                case "\r":
                    break // Swallowed; the \n that follows ends the row.
                case "\n":
                    endRow()
                default:
                    field.append(character)
                }
            }

            iterator = text.index(after: iterator)
        }

        if !field.isEmpty || !row.isEmpty {
            endRow()
        }

        return rows
    }
}
