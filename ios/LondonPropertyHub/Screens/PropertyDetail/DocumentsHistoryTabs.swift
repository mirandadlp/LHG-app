import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Documents

struct DocumentsTab: View {
    let store: PropertyStore
    let detail: PropertyDetail

    @Environment(SessionStore.self) private var session

    @State private var showsPicker = false
    @State private var documentType = "Floor Plan"
    @State private var notes = ""
    @State private var isUploading = false
    @State private var pendingDeletion: PropertyDocument?
    @State private var shareURL: URL?

    private var isReadOnly: Bool { !detail.permissions.canEdit }

    var body: some View {
        VStack(spacing: 16) {
            if !isReadOnly {
                HubCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Attach a Document").font(Theme.display(15))

                        LabelledField("Document type") {
                            MenuPicker(
                                selection: $documentType,
                                options: session.options("documentTypes"),
                                isReadOnly: false
                            )
                        }

                        LabelledField("Notes") {
                            TextField("", text: $notes)
                                .font(Theme.body(12))
                                .fieldChrome()
                        }

                        HubButton(
                            title: isUploading ? "Uploading…" : "Choose a file",
                            icon: "paperclip",
                            style: .amber,
                            isCompact: true,
                            isLoading: isUploading
                        ) {
                            showsPicker = true
                        }

                        Text("Floor plans, surveys, certificates and photographs belong here. Up to 20 MB per file.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if detail.documents.isEmpty {
                HubCard {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No documents yet",
                        message: "Floor plans, surveys and certificates belong here."
                    )
                }
            } else {
                ForEach(detail.documents) { document in
                    DocumentRow(
                        document: document,
                        isReadOnly: isReadOnly,
                        onShare: { share(document) },
                        onDelete: { pendingDeletion = document }
                    )
                }
            }
        }
        .fileImporter(
            isPresented: $showsPicker,
            allowedContentTypes: [.pdf, .image, .spreadsheet, .commaSeparatedText, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }

            isUploading = true

            Task {
                await store.uploadDocument(fileURL: url, type: documentType, notes: notes)
                isUploading = false
                notes = ""
                session.show("\(url.lastPathComponent) attached to this property.", style: .success)
            }
        }
        .sheet(item: Binding(get: { shareURL.map(ShareItem.init) }, set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
        .confirmationDialog(
            "Remove \(pendingDeletion?.name ?? "this document")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let document = pendingDeletion {
                    Task { await store.deleteDocument(document) }
                }
                pendingDeletion = nil
            }

            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        }
    }

    private func share(_ document: PropertyDocument) {
        Task {
            do {
                shareURL = try await PropertyAPI().downloadDocument(document)
            } catch {
                session.show(error: error)
            }
        }
    }
}

struct DocumentRow: View {
    let document: PropertyDocument
    let isReadOnly: Bool
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HubCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.amber)
                    .frame(width: 38, height: 38)
                    .background(Theme.lavenderSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.name)
                        .font(Theme.body(13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Chip(text: document.type, tone: .soft)

                        if !document.sizeLabel.isEmpty {
                            Text(document.sizeLabel)
                                .font(Theme.body(10))
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    Text("by: \(document.by ?? "Unknown") · \(document.date ?? "")")
                        .font(Theme.body(11).italic())
                        .foregroundStyle(Theme.muted)

                    if !document.notes.isEmpty {
                        Text(document.notes)
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.subtleInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.navy)
                            .frame(width: 32, height: 32)
                            .background(Theme.lavender, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(document.name)")

                    if !isReadOnly {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.red)
                                .frame(width: 32, height: 32)
                                .background(Theme.lavenderSoft, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(document.name)")
                    }
                }
            }
        }
    }

    private var icon: String {
        switch document.mimeType {
        case let mime? where mime.contains("pdf"): return "doc.richtext"
        case let mime? where mime.contains("image"): return "photo"
        case let mime? where mime.contains("sheet") || mime.contains("csv"): return "tablecells"
        default: return "doc.text"
        }
    }
}

// MARK: - History

struct HistoryTab: View {
    let detail: PropertyDetail

    var body: some View {
        VStack(spacing: 14) {
            HubCard {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.amber)

                    Text("Audit History · \(detail.history.count)")
                        .font(Theme.display(15))

                    Spacer()

                    if detail.pendingApprovalCount > 0 {
                        Chip(text: "\(detail.pendingApprovalCount) pending")
                    }
                }
            }

            if detail.history.isEmpty {
                HubCard {
                    EmptyStateView(
                        icon: "clock",
                        title: "No changes recorded yet",
                        message: "Every edit from here on is logged with who made it and why."
                    )
                }
            } else {
                ForEach(detail.history) { entry in
                    HistoryRow(entry: entry)
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: ChangeLogEntry

    var body: some View {
        HubCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(entry.field)
                        .font(Theme.body(13, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    approvalBadge
                }

                HStack(spacing: 8) {
                    Text(entry.prev)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.muted)
                        .strikethrough(entry.prev != "—", color: Theme.muted)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.muted)

                    Text(entry.next)
                        .font(Theme.body(12, weight: .heavy))
                        .foregroundStyle(Theme.navy)
                }

                Text("by: \(entry.by) · \(entry.date ?? "")")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(Theme.muted)

                if let reason = entry.reason, !reason.isEmpty {
                    Text(reason)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.subtleInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var approvalBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isApproved ? "star.fill" : "clock")
                .font(.system(size: 8))
                .foregroundStyle(entry.isApproved ? Theme.yellow : Color(hex: 0x8A6A10))

            Text(entry.approval)
                .font(Theme.body(10, weight: .heavy))
                .foregroundStyle(entry.isApproved ? Theme.green : Color(hex: 0x8A6A10))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(
            (entry.isApproved ? Theme.green.opacity(0.14) : Theme.yellow.opacity(0.2)),
            in: Capsule()
        )
    }
}

// MARK: - Missing information

struct MissingInformationSheet: View {
    let detail: PropertyDetail

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HubCard {
                        HStack(spacing: 16) {
                            CompletenessRing(percent: detail.completeness, size: 62, lineWidth: 7)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(detail.missing.required.count) required outstanding")
                                    .font(Theme.body(12, weight: .heavy))
                                    .foregroundStyle(detail.missing.required.isEmpty ? Theme.green : Theme.red)

                                Text("\(detail.missing.optional.count) optional outstanding")
                                    .font(Theme.body(12, weight: .heavy))
                                    .foregroundStyle(Theme.orange)

                                if detail.pendingApprovalCount > 0 {
                                    Text("\(detail.pendingApprovalCount) changes awaiting approval")
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.muted)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                    }

                    group("Required", detail.missing.required, tone: Theme.red)
                    group("Optional", detail.missing.optional, tone: Theme.orange)
                }
                .padding(20)
            }
            .background(Theme.lavender.ignoresSafeArea())
            .navigationTitle("Missing Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ fields: [PropertyDetail.MissingField], tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title) · \(fields.count)")
                .font(Theme.display(15))
                .foregroundStyle(tone)

            if fields.isEmpty {
                Text("Nothing outstanding.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(fields) { field in
                    HStack {
                        Text(field.label)
                            .font(Theme.body(12, weight: .semibold))
                            .foregroundStyle(Theme.ink)

                        Spacer(minLength: 8)

                        Text(field.section.shortLabel)
                            .font(Theme.body(10))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.lavenderSoft, in: Capsule())
                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - Share sheet

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Hands a downloaded file to the system share sheet so it can be saved to
/// Files, mailed, or opened in Excel.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
