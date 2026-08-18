import SwiftUI
import UniformTypeIdentifiers

/// Bringing legacy spreadsheets in. Upload, correct the column mapping, look at
/// the preview, then commit — nothing is written before that last step.
struct ImportScreen: View {
    let portfolio: PortfolioStore

    @Environment(SessionStore.self) private var session

    @State private var parse: ImportParse?
    @State private var isBusy = false
    @State private var busyLabel = ""
    @State private var showsPicker = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var editingHeader: String?

    private var importableCount: Int {
        parse?.preview.filter(\.importable).count ?? 0
    }

    private var unmappedCount: Int {
        parse?.mapping.values.filter(\.isEmpty).count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                VStack(spacing: 16) {
                    if let errorMessage {
                        InlineErrorView(message: errorMessage)
                    }

                    if let parse {
                        fileCard(parse)
                        mappingCard(parse)
                        previewCard(parse)
                        commitBar(parse)
                    } else {
                        uploadCard
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .fileImporter(
            isPresented: $showsPicker,
            allowedContentTypes: [.spreadsheet, .commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            upload(url)
        }
        .sheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: Binding(
            get: { editingHeader.map { HeaderSelection(header: $0) } },
            set: { editingHeader = $0?.header }
        )) { selection in
            if let parse {
                MappingPickerSheet(
                    header: selection.header,
                    current: parse.mapping[selection.header] ?? "",
                    targets: parse.targets
                ) { target in
                    remap(header: selection.header, to: target)
                }
            }
        }
    }

    private struct HeaderSelection: Identifiable {
        let header: String
        var id: String { header }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bring Legacy Data\nInto the Fold")
                .font(Theme.display(26))
                .foregroundStyle(.white)

            Text("Nothing is written until you review the preview and confirm.")
                .font(Theme.body(11))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(
            UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous)
        )
    }

    // MARK: - Upload

    private var uploadCard: some View {
        HubCard {
            VStack(spacing: 14) {
                EmptyStateView(
                    icon: "square.and.arrow.up",
                    title: "Upload an Excel or CSV file",
                    message: "The first sheet is read and its column headers matched to fields automatically. You can correct any match before importing."
                )

                HStack(spacing: 8) {
                    HubButton(
                        title: isBusy ? busyLabel : "Choose File",
                        style: .amber,
                        isCompact: true,
                        isLoading: isBusy
                    ) {
                        showsPicker = true
                    }

                    HubButton(title: "Sample File", icon: "arrow.down.doc", style: .subtle, isCompact: true) {
                        downloadSample()
                    }
                }
            }
        }
    }

    // MARK: - File summary

    private func fileCard(_ parse: ImportParse) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(parse.fileName)
                        .font(Theme.display(15))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    HubButton(title: "Start Over", style: .subtle, isCompact: true) {
                        self.parse = nil
                        errorMessage = nil
                    }
                }

                FlowLayout(spacing: 7) {
                    Chip(text: "\(parse.rows.count) rows", tone: .soft)
                    Chip(text: "\(parse.headers.count) columns", tone: .soft)
                    Chip(text: "\(unmappedCount) unmatched")
                }
            }
        }
    }

    // MARK: - Mapping

    private func mappingCard(_ parse: ImportParse) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Map Columns to Fields").font(Theme.display(15))

                Text("Tap a column to change where its values land, or set it to not import.")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)

                ForEach(parse.headers, id: \.self) { header in
                    let target = parse.mapping[header] ?? ""

                    Button {
                        editingHeader = header
                    } label: {
                        HStack(spacing: 10) {
                            Text(header)
                                .font(Theme.body(11, weight: .semibold))
                                .foregroundStyle(Theme.subtleInk)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Theme.lavenderSoft, in: Capsule())

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.muted)

                            Text(label(for: target, in: parse))
                                .font(Theme.body(11, weight: .heavy))
                                .foregroundStyle(target.isEmpty ? Theme.subtleInk : .white)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(target.isEmpty ? Color(hex: 0xE3E5F0) : Theme.navy, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func label(for target: String, in parse: ImportParse) -> String {
        target.isEmpty
            ? "Do not import"
            : parse.targets.first { $0.id == target }?.label ?? target
    }

    // MARK: - Preview

    private func previewCard(_ parse: ImportParse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Preview") {
                Chip(text: "\(importableCount) ready", tone: importableCount > 0 ? .yellow : .soft)
            }

            ForEach(parse.preview) { row in
                HubCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top) {
                            Text(row.siteName.isEmpty ? "No site name" : row.siteName)
                                .font(Theme.body(13, weight: .heavy))
                                .foregroundStyle(row.siteName.isEmpty ? Theme.red : Theme.ink)

                            Spacer(minLength: 8)

                            Chip(text: "\(row.totalUnits) units", tone: .soft)
                        }

                        Text(row.borough)
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)

                        if row.duplicate {
                            Label(row.duplicateReason ?? "Duplicate — will be skipped", systemImage: "exclamationmark.triangle.fill")
                                .font(Theme.body(11, weight: .semibold))
                                .foregroundStyle(Theme.red)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if !row.missingRequired.isEmpty {
                            Label("Missing: \(row.missingRequired.joined(separator: ", "))", systemImage: "info.circle")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Label("Ready to import", systemImage: "star.fill")
                                .font(Theme.body(11, weight: .semibold))
                                .foregroundStyle(Theme.green)
                        }
                    }
                }
                .opacity(row.duplicate ? 0.65 : 1)
            }
        }
    }

    // MARK: - Commit

    private func commitBar(_ parse: ImportParse) -> some View {
        VStack(spacing: 10) {
            if importableCount == 0 {
                Text("Nothing in this file can be imported. Every row is either a duplicate or has no site name.")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                HubButton(title: "Cancel", style: .subtle, isCompact: true) {
                    self.parse = nil
                }

                HubButton(
                    title: "Import \(importableCount) \(importableCount == 1 ? "Property" : "Properties")",
                    icon: "tray.and.arrow.down",
                    style: .amber,
                    isCompact: true,
                    isLoading: isBusy,
                    isDisabled: importableCount == 0
                ) {
                    commit(parse)
                }
            }
        }
    }

    // MARK: - Actions

    private func upload(_ url: URL) {
        isBusy = true
        busyLabel = "Reading…"
        errorMessage = nil

        Task {
            defer { isBusy = false }

            do {
                parse = try await PropertyAPI().importPreview(fileURL: url)
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func remap(header: String, to target: String) {
        guard var current = parse else { return }

        current.mapping[header] = target
        parse = current

        Task {
            do {
                let preview = try await PropertyAPI().importRemap(rows: current.rows, mapping: current.mapping)
                parse?.preview = preview
            } catch {
                session.show(error: error)
            }
        }
    }

    private func commit(_ parse: ImportParse) {
        isBusy = true
        busyLabel = "Importing…"

        Task {
            defer { isBusy = false }

            do {
                let result = try await PropertyAPI().importCommit(
                    rows: parse.rows,
                    mapping: parse.mapping,
                    fileName: parse.fileName
                )

                self.parse = nil
                await portfolio.reload()

                let skipped = result.skipped > 0 ? " \(result.skipped) skipped." : ""
                session.show(result.message + skipped, style: .success)
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func downloadSample() {
        Task {
            do {
                shareURL = try await PropertyAPI().downloadSampleSpreadsheet()
            } catch {
                session.show(error: error)
            }
        }
    }
}

// MARK: - Mapping picker

struct MappingPickerSheet: View {
    let header: String
    let current: String
    let targets: [ImportTarget]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(id: "", label: "Do not import")
                } footer: {
                    Text("Values in this column will be ignored.")
                }

                Section("Property fields") {
                    ForEach(targets.filter { !$0.id.hasPrefix("accom:") }) { target in
                        row(id: target.id, label: target.label)
                    }
                }

                Section("Accommodation counts") {
                    ForEach(targets.filter { $0.id.hasPrefix("accom:") }) { target in
                        row(id: target.id, label: target.label)
                    }
                }
            }
            .navigationTitle(header)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(id: String, label: String) -> some View {
        Button {
            onSelect(id)
            dismiss()
        } label: {
            HStack {
                Text(label).foregroundStyle(Theme.ink)

                Spacer()

                if current == id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.navy)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
