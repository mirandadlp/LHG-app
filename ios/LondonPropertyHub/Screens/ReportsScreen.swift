import SwiftUI

struct ReportsScreen: View {
    @Bindable var portfolio: PortfolioStore
    let onOpenFilters: () -> Void

    @Environment(SessionStore.self) private var session

    @State private var columns: [String] = []
    @State private var report: ReportPayload?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var exportingFormat: PropertyAPI.ExportFormat?
    @State private var shareURL: URL?
    @State private var showsColumnPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HubHeader(
                    title: "Board-Ready in\nOne Export",
                    subtitle: "Choose the columns, apply filters, then export. Files contain exactly what you see.",
                    searchText: $portfolio.filters.query,
                    searchPrompt: "Search the report",
                    filterCount: portfolio.filters.activeCount,
                    onOpenFilters: onOpenFilters
                )

                VStack(spacing: 16) {
                    summaryCard
                    exportCard

                    if isLoading, report == nil {
                        ProgressView().tint(Theme.navy).padding(.vertical, 40)
                    } else if let loadError {
                        InlineErrorView(message: loadError) { Task { await load() } }
                    } else if let report {
                        tableCard(report)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await load() }
        .task {
            if columns.isEmpty { columns = session.defaultReportColumns }
            await load()
        }
        .onChange(of: portfolio.filters) { _, _ in
            Task { await load() }
        }
        .onChange(of: columns) { _, _ in
            Task { await load() }
        }
        .sheet(isPresented: $showsColumnPicker) {
            ColumnPickerSheet(selected: $columns, available: session.reportColumns)
        }
        .sheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
    }

    // MARK: - Cards

    private var summaryCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Property Portfolio Report").font(Theme.display(15))

                HStack(spacing: 8) {
                    Chip(text: "\(report?.propertyCount ?? portfolio.properties.count) properties")
                    Chip(text: "\((report?.unitCount ?? portfolio.totalUnits).formattedCount) units", tone: .soft)
                }

                Text(portfolio.filters.isActive ? "Filtered selection" : "Entire company")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(Theme.muted)

                Divider().overlay(Theme.hairline)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Columns")
                            .font(Theme.body(12, weight: .bold))
                            .foregroundStyle(Theme.navy)

                        Text("\(columns.count) of \(session.reportColumns.count) selected")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    HubButton(title: "Choose", icon: "slider.horizontal.3", style: .subtle, isCompact: true) {
                        showsColumnPicker = true
                    }
                }
            }
        }
    }

    private var exportCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Export").font(Theme.display(15))

                Text("The file is prepared on the server and handed to the share sheet, so you can save it to Files or send it on.")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 8) {
                    ForEach(PropertyAPI.ExportFormat.allCases) { format in
                        HubButton(
                            title: format.label,
                            icon: format.systemImage,
                            style: format == .xlsx ? .amber : .subtle,
                            isCompact: true,
                            isLoading: exportingFormat == format
                        ) {
                            export(format, entirePortfolio: false)
                        }
                    }

                    HubButton(title: "Entire Portfolio", icon: "square.and.arrow.up", style: .primary, isCompact: true) {
                        export(.xlsx, entirePortfolio: true)
                    }
                }
            }
        }
    }

    private func tableCard(_ report: ReportPayload) -> some View {
        HubCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header band
                        HStack(spacing: 0) {
                            ForEach(report.columns, id: \.self) { column in
                                Text(column.uppercased())
                                    .font(Theme.body(9, weight: .heavy))
                                    .kerning(0.5)
                                    .foregroundStyle(.white)
                                    .frame(width: width(for: column), alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 11)
                            }
                        }
                        .background(Theme.navy)

                        ForEach(Array(report.rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 0) {
                                ForEach(report.columns, id: \.self) { column in
                                    Text(row[column]?.display ?? "")
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.subtleInk)
                                        .lineLimit(1)
                                        .frame(width: width(for: column), alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                }
                            }
                            .background(index.isMultiple(of: 2) ? Color.white : Theme.lavenderSoft.opacity(0.5))
                        }

                        // Company total
                        HStack(spacing: 0) {
                            ForEach(report.columns, id: \.self) { column in
                                Text(report.totals[column]?.display ?? "")
                                    .font(Theme.body(11, weight: .heavy))
                                    .foregroundStyle(Color(hex: 0x8A6A10))
                                    .lineLimit(1)
                                    .frame(width: width(for: column), alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 11)
                            }
                        }
                        .background(Theme.yellow.opacity(0.18))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
    }

    /// Wide columns for prose, narrow for counts, so the table stays readable
    /// without wrapping every cell.
    private func width(for column: String) -> CGFloat {
        switch column {
        case "Address": return 230
        case "Site", "Council", "Manager", "Property type": return 160
        case "Verification status", "Last updated": return 140
        case "Borough", "Region", "Step-free entrance": return 120
        default: return 92
        }
    }

    // MARK: - Actions

    private func load() async {
        guard !columns.isEmpty else { return }

        isLoading = true
        loadError = nil

        defer { isLoading = false }

        do {
            report = try await PropertyAPI().report(filters: portfolio.filters, columns: columns)
        } catch {
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func export(_ format: PropertyAPI.ExportFormat, entirePortfolio: Bool) {
        exportingFormat = format

        Task {
            defer { exportingFormat = nil }

            do {
                shareURL = try await PropertyAPI().exportReport(
                    format: format,
                    filters: portfolio.filters,
                    columns: columns,
                    entirePortfolio: entirePortfolio
                )
            } catch {
                session.show(error: error)
            }
        }
    }
}

// MARK: - Column picker

struct ColumnPickerSheet: View {
    @Binding var selected: [String]
    let available: [String]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(available, id: \.self) { column in
                        Button {
                            toggle(column)
                        } label: {
                            HStack {
                                Text(column).foregroundStyle(Theme.ink)

                                Spacer()

                                if selected.contains(column) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.navy)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Columns")
                } footer: {
                    Text("Exports contain exactly the columns selected here, in this order, plus the company-total row.")
                }
            }
            .navigationTitle("Report Columns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle(_ column: String) {
        if let index = selected.firstIndex(of: column) {
            // Never let the table become empty — one column has to remain.
            guard selected.count > 1 else { return }
            selected.remove(at: index)
        } else {
            // Keep the canonical order rather than order-of-tapping.
            selected = available.filter { selected.contains($0) || $0 == column }
        }
    }
}
