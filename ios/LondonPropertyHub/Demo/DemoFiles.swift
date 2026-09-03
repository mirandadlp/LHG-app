import Foundation
import UIKit

/// Files the demo hands to the share sheet.
///
/// Exports are the one place a fake backend is tempting to fake twice — return
/// a text file and call it a spreadsheet. It would show up the moment anyone
/// opened it, so these are the real formats: a proper CSV, a real `.xlsx`
/// package, and a rendered PDF.
enum DemoFiles {

    // MARK: - Plain files

    static func write(_ data: Data, named name: String) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        try? FileManager.default.removeItem(at: destination)
        try data.write(to: destination, options: .atomic)

        return destination
    }

    static func mimeType(forExtension ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        case "csv": return "text/csv"
        case "txt": return "text/plain"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default: return "application/octet-stream"
        }
    }

    // MARK: - CSV

    static func writeCSV(_ rows: [[String]], named name: String) throws -> URL {
        let body = rows.map { row in row.map(escape).joined(separator: ",") }.joined(separator: "\r\n")

        // The BOM is what makes Excel open a UTF-8 CSV without mangling "m²".
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(body.utf8))

        return try write(data, named: name)
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }

        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Excel

    /// A minimal but valid SpreadsheetML package: one sheet, inline strings for
    /// text and real numbers for numbers, so totals stay summable in Excel.
    static func writeXLSX(_ rows: [[String]], sheetName: String, named name: String) throws -> URL {
        var sheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
        """

        for (rowIndex, row) in rows.enumerated() {
            sheet += "<row r=\"\(rowIndex + 1)\">"

            for (columnIndex, value) in row.enumerated() {
                let reference = "\(columnName(columnIndex))\(rowIndex + 1)"

                if let number = Double(value), !value.isEmpty {
                    sheet += "<c r=\"\(reference)\"><v>\(trim(number))</v></c>"
                } else if !value.isEmpty {
                    sheet += "<c r=\"\(reference)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(value))</t></is></c>"
                }
            }

            sheet += "</row>"
        }

        sheet += "</sheetData></worksheet>"

        let package: [(String, String)] = [
            ("[Content_Types].xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
            </Types>
            """),
            ("_rels/.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
            </Relationships>
            """),
            ("xl/workbook.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" \
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
            <sheets><sheet name="\(xml(sheetName))" sheetId="1" r:id="rId1"/></sheets></workbook>
            """),
            ("xl/_rels/workbook.xml.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\
            </Relationships>
            """),
            ("xl/worksheets/sheet1.xml", sheet),
        ]

        let entries = package.map { Zip.Entry(name: $0.0, data: Data($0.1.utf8)) }

        return try write(Zip.archive(entries), named: name)
    }

    /// 0 → A, 25 → Z, 26 → AA.
    private static func columnName(_ index: Int) -> String {
        var name = ""
        var remaining = index

        repeat {
            name = String(UnicodeScalar(UInt8(65 + remaining % 26))) + name
            remaining = remaining / 26 - 1
        } while remaining >= 0

        return name
    }

    private static func xml(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    // MARK: - PDF

    /// A4 portrait, the header row repeated on every page, the last row —
    /// always the company total — in bold, matching the on-screen table.
    @MainActor
    static func writePDF(_ rows: [[String]], title: String, subtitle: String, named name: String) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 32
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        let header = rows.first ?? []
        let body = Array(rows.dropFirst())
        let columnWidth = header.isEmpty ? 0 : (page.width - margin * 2) / CGFloat(header.count)

        let titleFont = UIFont.systemFont(ofSize: 15, weight: .bold)
        let subtitleFont = UIFont.systemFont(ofSize: 9)
        let headerFont = UIFont.systemFont(ofSize: 7, weight: .semibold)
        let cellFont = UIFont.systemFont(ofSize: 7)

        let data = renderer.pdfData { context in
            var y: CGFloat = 0

            func startPage() {
                context.beginPage()

                title.draw(at: CGPoint(x: margin, y: margin),
                           withAttributes: [.font: titleFont, .foregroundColor: UIColor.black])
                subtitle.draw(at: CGPoint(x: margin, y: margin + 20),
                              withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])

                y = margin + 44

                draw(header, at: y, columnWidth: columnWidth, margin: margin, font: headerFont, colour: .black)

                y += 14

                context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
                context.cgContext.setLineWidth(0.5)
                context.cgContext.move(to: CGPoint(x: margin, y: y - 3))
                context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: y - 3))
                context.cgContext.strokePath()
            }

            startPage()

            for (index, row) in body.enumerated() {
                if y > page.height - margin - 20 {
                    startPage()
                }

                let isTotals = index == body.count - 1

                draw(
                    row,
                    at: y,
                    columnWidth: columnWidth,
                    margin: margin,
                    font: isTotals ? headerFont : cellFont,
                    colour: isTotals ? .black : .darkGray
                )

                y += 12
            }
        }

        return try write(data, named: name)
    }

    /// Stands in for a document that was migrated from the legacy system and has
    /// no binary attached — the demo says so on the page rather than handing
    /// over an empty file.
    @MainActor
    static func placeholderPDF(named name: String, type: String) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)

        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            context.beginPage()

            name.draw(
                at: CGPoint(x: 48, y: 64),
                withAttributes: [.font: UIFont.systemFont(ofSize: 16, weight: .bold)]
            )

            """
            \(type)

            This is demo data. The record for this document exists, but no file \
            was ever attached to it — upload one to replace this placeholder.
            """
            .draw(
                in: CGRect(x: 48, y: 96, width: page.width - 96, height: 200),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkGray,
                ]
            )
        }

        return try write(data, named: name.hasSuffix(".pdf") ? name : name + ".pdf")
    }

    @MainActor
    private static func draw(
        _ row: [String],
        at y: CGFloat,
        columnWidth: CGFloat,
        margin: CGFloat,
        font: UIFont,
        colour: UIColor
    ) {
        for (index, value) in row.enumerated() {
            let box = CGRect(x: margin + CGFloat(index) * columnWidth, y: y, width: columnWidth - 4, height: 11)

            (value as NSString).draw(
                with: box,
                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: [.font: font, .foregroundColor: colour],
                context: nil
            )
        }
    }
}

// MARK: - Zip

/// Just enough of the ZIP format to build an `.xlsx`: stored (uncompressed)
/// entries, one central directory, no zip64. Everything the demo writes is a
/// few kilobytes of XML, so compression would buy nothing worth the code.
enum Zip {

    struct Entry {
        let name: String
        let data: Data
    }

    static func archive(_ entries: [Entry]) -> Data {
        var payload = Data()
        var directory = Data()

        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = crc32(entry.data)
            let offset = UInt32(payload.count)

            payload.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            payload.append(uint16(20))          // version needed
            payload.append(uint16(0))           // flags
            payload.append(uint16(0))           // stored
            payload.append(uint16(0))           // modification time — 00:00
            payload.append(uint16(dosDate))     // modification date
            payload.append(uint32(crc))
            payload.append(uint32(UInt32(entry.data.count)))
            payload.append(uint32(UInt32(entry.data.count)))
            payload.append(uint16(UInt16(name.count)))
            payload.append(uint16(0))           // extra field length
            payload.append(name)
            payload.append(entry.data)

            directory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            directory.append(uint16(20))        // version made by
            directory.append(uint16(20))        // version needed
            directory.append(uint16(0))
            directory.append(uint16(0))
            directory.append(uint16(0))
            directory.append(uint16(dosDate))
            directory.append(uint32(crc))
            directory.append(uint32(UInt32(entry.data.count)))
            directory.append(uint32(UInt32(entry.data.count)))
            directory.append(uint16(UInt16(name.count)))
            directory.append(uint16(0))         // extra
            directory.append(uint16(0))         // comment
            directory.append(uint16(0))         // disk number
            directory.append(uint16(0))         // internal attributes
            directory.append(uint32(0))         // external attributes
            directory.append(uint32(offset))
            directory.append(name)
        }

        var archive = payload
        let directoryOffset = UInt32(archive.count)

        archive.append(directory)
        archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        archive.append(uint16(0))
        archive.append(uint16(0))
        archive.append(uint16(UInt16(entries.count)))
        archive.append(uint16(UInt16(entries.count)))
        archive.append(uint32(UInt32(directory.count)))
        archive.append(uint32(directoryOffset))
        archive.append(uint16(0))               // comment length

        return archive
    }

    /// 1 January 2016 in the MS-DOS date format ZIP has carried since 1989:
    /// seven bits of year from 1980, four of month, five of day.
    private static let dosDate: UInt16 = (36 << 9) | (1 << 5) | 1

    private static func uint16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    private static func uint32(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ])
    }

    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        (0..<8).reduce(UInt32(index)) { value, _ in
            value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF

        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }

        return crc ^ 0xFFFF_FFFF
    }
}
