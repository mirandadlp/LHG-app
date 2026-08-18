import SwiftUI

struct ApprovalsScreen: View {
    @Bindable var portfolio: PortfolioStore

    @Environment(SessionStore.self) private var session
    @State private var busyID: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HubHeader(
                    title: "Verified by the\nPeople on the Ground",
                    subtitle: "Review what property managers have submitted, then approve it or send it back",
                    searchText: $portfolio.filters.query,
                    searchPrompt: "Search submissions",
                    filterCount: portfolio.filters.activeCount,
                    onOpenFilters: {}
                )

                VStack(spacing: 16) {
                    awaitingSection
                    roundsSection
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable { await portfolio.reload() }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Awaiting review

    private var awaitingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Awaiting Review") {
                Chip(text: "\(portfolio.awaitingReview.count)")
            }

            if portfolio.awaitingReview.isEmpty {
                HubCard {
                    EmptyStateView(
                        icon: "checkmark.seal",
                        title: "Nothing waiting for review",
                        message: session.canReview
                            ? "Request verification below to start a round."
                            : "Submit a property record to send it here."
                    )
                }
            } else {
                ForEach(portfolio.awaitingReview) { property in
                    SubmissionCard(
                        property: property,
                        canReview: session.canReview,
                        isBusy: busyID == property.id,
                        onApprove: { comment in act(property, approve: true, comment: comment) },
                        onRequestChanges: { comment in act(property, approve: false, comment: comment) }
                    )
                }
            }
        }
    }

    // MARK: - Other rounds

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Verification Rounds")

            if portfolio.otherRounds.isEmpty {
                HubCard {
                    Text("Every property in this view has been submitted.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ForEach(portfolio.otherRounds) { property in
                    HubCard(padding: 14) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                NavigationLink(value: property) {
                                    Text(property.siteName)
                                        .font(Theme.body(13, weight: .heavy))
                                        .foregroundStyle(Theme.navy)
                                        .underline()
                                        .multilineTextAlignment(.leading)
                                }
                                .buttonStyle(.plain)

                                Text("by: \(property.managerLabel) · \(property.borough ?? "—")")
                                    .font(Theme.body(11).italic())
                                    .foregroundStyle(Theme.muted)

                                StatusPill(status: property.verification, small: true)
                            }

                            Spacer(minLength: 6)

                            if session.canReview {
                                HubButton(
                                    title: "Request",
                                    style: .ghost,
                                    isCompact: true,
                                    isLoading: busyID == property.id
                                ) {
                                    requestVerification(property)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func act(_ property: PropertySummary, approve: Bool, comment: String?) {
        busyID = property.id

        Task {
            defer { busyID = nil }

            do {
                let api = PropertyAPI()
                let updated = approve
                    ? try await api.approve(id: property.id, comment: comment)
                    : try await api.requestChanges(id: property.id, comment: comment)

                portfolio.apply(updated)
                await portfolio.reload()

                session.show(
                    "\(property.siteName) marked as \(updated.verification.rawValue).",
                    style: .success
                )
            } catch {
                session.show(error: error)
            }
        }
    }

    private func requestVerification(_ property: PropertySummary) {
        busyID = property.id

        Task {
            defer { busyID = nil }

            do {
                let updated = try await PropertyAPI().requestVerification(id: property.id)
                portfolio.apply(updated)
                await portfolio.reload()

                session.show(
                    "Verification requested from \(property.managerLabel).",
                    style: .success
                )
            } catch {
                session.show(error: error)
            }
        }
    }
}

// MARK: - Submission card

struct SubmissionCard: View {
    let property: PropertySummary
    let canReview: Bool
    let isBusy: Bool
    let onApprove: (String?) -> Void
    let onRequestChanges: (String?) -> Void

    @State private var comment = ""

    var body: some View {
        HubCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    NavigationLink(value: property) {
                        Text(property.siteName)
                            .font(Theme.body(14, weight: .heavy))
                            .foregroundStyle(Theme.navy)
                            .underline()
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 8)

                    Chip(text: "\(property.completeness)%")
                }

                Text("by: \(property.managerLabel)")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(Theme.muted)

                if let lastUpdated = property.lastUpdated {
                    Text("Last change \(lastUpdated)")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.subtleInk)
                }

                if property.openFlagCount > 0 {
                    Label(
                        "\(property.openFlagCount) unconfirmed large \(property.openFlagCount == 1 ? "change" : "changes")",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(Theme.body(11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8A6A10))
                }

                if canReview {
                    TextField("Add a comment for the property manager", text: $comment, axis: .vertical)
                        .lineLimit(1...3)
                        .font(Theme.body(12))
                        .fieldChrome()

                    HStack(spacing: 8) {
                        HubButton(
                            title: "Approve",
                            icon: "checkmark.circle",
                            style: .amber,
                            isCompact: true,
                            isLoading: isBusy
                        ) {
                            onApprove(comment.isEmpty ? nil : comment)
                        }

                        HubButton(title: "Request Changes", style: .subtle, isCompact: true) {
                            onRequestChanges(comment.isEmpty ? nil : comment)
                        }
                    }
                }
            }
        }
    }
}
