import SwiftUI

struct PropertyDetailScreen: View {
    let propertyID: Int
    let portfolio: PortfolioStore

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var store: PropertyStore
    @State private var tab: DetailTab = .overview
    @State private var showsMissing = false
    @State private var reviewAction: ReviewAction?

    init(propertyID: Int, portfolio: PortfolioStore) {
        self.propertyID = propertyID
        self.portfolio = portfolio
        _store = State(initialValue: PropertyStore(propertyID: propertyID))
    }

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case general = "General"
        case accommodation = "Accommodation"
        case dimensions = "Dimensions"
        case elevators = "Elevators"
        case staircases = "Staircases"
        case accessibility = "Accessibility"
        case building = "Building"
        case documents = "Documents"
        case history = "History"

        var id: String { rawValue }

        /// The four tabs that render straight from a registry section.
        var section: FieldSection? {
            switch self {
            case .general: return .general
            case .dimensions: return .dimensions
            case .accessibility: return .accessibility
            case .building: return .building
            default: return nil
            }
        }
    }

    struct ReviewAction: Identifiable {
        enum Kind { case approve, requestChanges }

        let kind: Kind
        var id: String { kind == .approve ? "approve" : "changes" }

        var title: String { kind == .approve ? "Approve this record" : "Request changes" }

        var message: String {
            kind == .approve
                ? "Marks the record verified and approves every pending edit."
                : "Sends the record back to the property manager with your comment."
        }
    }

    var body: some View {
        ScrollView {
            if let detail = store.detail {
                VStack(spacing: 18) {
                    PropertyHeaderCard(
                        detail: detail,
                        isSaving: store.isSaving,
                        onShowMissing: { showsMissing = true },
                        onSubmit: submit,
                        onApprove: { reviewAction = ReviewAction(kind: .approve) },
                        onRequestChanges: { reviewAction = ReviewAction(kind: .requestChanges) }
                    )

                    if !detail.flags.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(detail.flags) { flag in
                                LargeChangeBanner(flag: flag, isReadOnly: !detail.permissions.canEdit) { confirm in
                                    Task { await store.resolveFlag(flag, confirm: confirm) }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    tabStrip

                    Group {
                        switch tab {
                        case .overview:
                            OverviewTab(detail: detail, onShowMissing: { showsMissing = true })

                        case .accommodation:
                            AccommodationTab(store: store, detail: detail)

                        case .elevators:
                            ElevatorsTab(store: store, detail: detail)

                        case .staircases:
                            StaircasesTab(store: store, detail: detail)

                        case .documents:
                            DocumentsTab(store: store, detail: detail)

                        case .history:
                            HistoryTab(detail: detail)

                        default:
                            if let section = tab.section {
                                FieldSectionTab(store: store, detail: detail, section: section)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 36)
            } else if store.isLoading {
                ProgressView().tint(Theme.navy).padding(.vertical, 80)
            } else if let error = store.loadError {
                InlineErrorView(message: error) {
                    Task { await store.load() }
                }
                .padding(20)
            }
        }
        .background(Theme.lavender.ignoresSafeArea())
        .navigationTitle(store.detail?.siteName ?? "Property")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await store.load() }
        .task {
            store.onChange = { detail in
                guard let detail else { return }
                portfolio.apply(detail)
            }
            store.onError = { error in session.show(error: error) }

            await store.load()
        }
        .onDisappear {
            // Flush anything still inside its debounce window so a fast
            // back-swipe never loses the last edit.
            Task { await store.flushPendingEdits() }
        }
        .sheet(isPresented: $showsMissing) {
            if let detail = store.detail {
                MissingInformationSheet(detail: detail)
            }
        }
        .sheet(item: $reviewAction) { action in
            ReviewCommentSheet(action: action) { comment in
                Task {
                    switch action.kind {
                    case .approve: await store.approve(comment: comment)
                    case .requestChanges: await store.requestChanges(comment: comment)
                    }

                    session.show(
                        action.kind == .approve ? "Property verified." : "Sent back to the property manager.",
                        style: .success
                    )
                }
            }
        }
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DetailTab.allCases) { entry in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { tab = entry }
                        } label: {
                            Text(entry.rawValue)
                                .font(Theme.body(12, weight: .heavy))
                                .foregroundStyle(tab == entry ? .white : Theme.muted)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background(tab == entry ? Theme.navy : Color.white, in: Capsule())
                                .overlay {
                                    if tab != entry { Capsule().stroke(Theme.hairline, lineWidth: 1) }
                                }
                                .shadow(color: tab == entry ? Theme.navy.opacity(0.3) : .clear, radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .id(entry)
                        .accessibilityAddTraits(tab == entry ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: tab) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }

    private func submit() {
        Task {
            if let missing = await store.submit() {
                if !missing.isEmpty { showsMissing = true }
            } else {
                session.show("Submitted for review. Corporate will approve or send it back.", style: .success)
            }
        }
    }
}

// MARK: - Header

struct PropertyHeaderCard: View {
    let detail: PropertyDetail
    let isSaving: Bool
    let onShowMissing: () -> Void
    let onSubmit: () -> Void
    let onApprove: () -> Void
    let onRequestChanges: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    CompletenessRing(percent: detail.completeness, size: 66, lineWidth: 7, onDark: true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(detail.siteName)
                            .font(Theme.display(22))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 5) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.yellow)

                            Text(detail.fullAddress)
                                .font(Theme.body(12))
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }

                FlowLayout(spacing: 7) {
                    StatusPill(status: detail.verification)

                    if let borough = detail.values["borough"]?.stringValue, !borough.isEmpty {
                        Chip(text: borough)
                    }

                    if let type = detail.values["propertyType"]?.stringValue, !type.isEmpty {
                        Chip(text: type)
                    }

                    if !detail.permissions.canEdit {
                        Chip(text: "Read-Only", tone: .navy)
                    }
                }
                .padding(.top, 14)

                Text("by: \(detail.managerLabel)")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)

                FlowLayout(spacing: 8) {
                    HubButton(title: "Missing Information", style: .yellow, isCompact: true, action: onShowMissing)

                    if detail.permissions.canSubmit {
                        HubButton(title: "Submit for Review", icon: "checkmark.circle", style: .white, isCompact: true, action: onSubmit)
                    }

                    if detail.permissions.canReview, detail.verification == .submitted {
                        HubButton(title: "Approve", style: .yellow, isCompact: true, action: onApprove)
                        HubButton(title: "Request Changes", style: .white, isCompact: true, action: onRequestChanges)
                    }
                }
                .padding(.top, 16)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.heroGradient)

            if detail.permissions.canEdit {
                HStack(spacing: 6) {
                    if isSaving {
                        ProgressView().controlSize(.mini).tint(Color(hex: 0x8A6A10))
                        Text("Saving…")
                    } else {
                        Image(systemName: "star.fill").font(.system(size: 9))
                        Text("Changes save as you type and are written to the audit history automatically.")
                    }

                    Spacer(minLength: 0)
                }
                .font(Theme.body(11, weight: .bold))
                .foregroundStyle(Color(hex: 0x8A6A10))
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.yellow.opacity(0.16))
                .animation(.easeInOut(duration: 0.2), value: isSaving)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.heroRadius, style: .continuous))
        .shadow(color: Theme.navy.opacity(0.2), radius: 16, y: 8)
        .padding(.horizontal, 20)
    }
}

// MARK: - Large change banner

struct LargeChangeBanner: View {
    let flag: ChangeFlag
    let isReadOnly: Bool
    let onResolve: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: 0x8A6A10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Large change detected — \(flag.label)")
                        .font(Theme.body(12, weight: .heavy))

                    Text("Previous value: \(flag.prev). New value: \(flag.next). Please confirm this is correct.")
                        .font(Theme.body(12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color(hex: 0x6E540C))
            }

            if !isReadOnly {
                HStack(spacing: 8) {
                    HubButton(title: "Confirm", style: .primary, isCompact: true) { onResolve(true) }
                    HubButton(title: "Revert to \(flag.prev)", style: .subtle, isCompact: true) { onResolve(false) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.yellow.opacity(0.18), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.yellow, lineWidth: 1.5)
        )
    }
}

// MARK: - Review comment sheet

struct ReviewCommentSheet: View {
    let action: PropertyDetailScreen.ReviewAction
    let onConfirm: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Comment for the property manager", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Comment")
                } footer: {
                    Text(action.message)
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action.kind == .approve ? "Approve" : "Send back") {
                        onConfirm(comment.isEmpty ? nil : comment)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
