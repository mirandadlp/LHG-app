import SwiftUI

struct DirectoryScreen: View {
    @Bindable var portfolio: PortfolioStore
    let onOpenFilters: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var showsNewProperty = false

    /// Split out of `body` so each branch type-checks on its own. Long view
    /// bodies with several branches are where the compiler starts to struggle.
    @ViewBuilder
    private var listContent: some View {
        if portfolio.isLoading, portfolio.properties.isEmpty {
            ProgressView().tint(Theme.navy).padding(.vertical, 50)
        } else if let error = portfolio.loadError, portfolio.properties.isEmpty {
            InlineErrorView(message: error) {
                Task { await portfolio.reload() }
            }
        } else if portfolio.properties.isEmpty {
            HubCard { emptyState }
        } else {
            LazyVStack(spacing: 14) {
                ForEach(portfolio.properties) { property in
                    NavigationLink(value: PropertyRoute(property)) {
                        PropertyCard(property: property)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Two straight-line constructions rather than one with ternaries feeding
    /// its optional parameters. A conditional between a function reference and
    /// `nil` gives the type checker more to solve than it reliably can — the
    /// compiler reports it as a failure to produce a diagnostic, which is no
    /// help at all. An `if` and explicit arguments leave nothing to infer.
    private var emptyState: EmptyStateView {
        if portfolio.filters.isActive {
            return EmptyStateView(
                icon: "building.2",
                title: "No properties match",
                message: "Nothing matches these filters. Reset the scope to see the whole company.",
                actionTitle: "Clear filters",
                action: { portfolio.filters.clear() }
            )
        }

        return EmptyStateView(
            icon: "building.2",
            title: "No properties match",
            message: "There are no properties in your portfolio yet.",
            actionTitle: nil,
            action: nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HubHeader(
                    title: "Every Property,\nOne Record Each",
                    subtitle: "We make sure every figure is verified by the expert on the ground",
                    searchText: $portfolio.filters.query,
                    searchPrompt: "Search properties",
                    filterCount: portfolio.filters.activeCount,
                    onOpenFilters: onOpenFilters
                )

                VStack(spacing: 14) {
                    SectionHeading("All Properties") {
                        if session.canCreateProperties {
                            HubButton(title: "Add", icon: "plus", style: .amber, isCompact: true) {
                                showsNewProperty = true
                            }
                        }
                    }

                    listContent
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable { await portfolio.reload() }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsNewProperty) {
            NewPropertySheet(portfolio: portfolio)
        }
    }
}

// MARK: - Explore

struct ExploreScreen: View {
    @Bindable var portfolio: PortfolioStore
    let onOpenFilters: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HubHeader(
                    title: "Find Anything in\nYour Portfolio",
                    subtitle: "Search by name, address, borough, council, region or manager",
                    searchText: $portfolio.filters.query,
                    searchPrompt: "Search here",
                    filterCount: portfolio.filters.activeCount,
                    onOpenFilters: onOpenFilters
                )

                VStack(spacing: 14) {
                    SectionHeading(resultsTitle) {
                        Text("\(portfolio.properties.count) \(portfolio.properties.count == 1 ? "result" : "results")")
                            .font(Theme.body(11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }

                    if portfolio.isLoading, portfolio.properties.isEmpty {
                        ProgressView().tint(Theme.navy).padding(.vertical, 50)
                    } else if portfolio.properties.isEmpty {
                        HubCard {
                            EmptyStateView(
                                icon: "magnifyingglass",
                                title: "Nothing found",
                                message: portfolio.filters.query.isEmpty
                                    ? "Adjust your filters to see results."
                                    : "Nothing matches \"\(portfolio.filters.query)\". Try a borough, postcode or manager name."
                            )
                        }
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(portfolio.properties) { property in
                                NavigationLink(value: PropertyRoute(property)) {
                                    PropertyCard(property: property, showsRing: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable { await portfolio.reload() }
        .scrollDismissesKeyboard(.interactively)
    }

    private var resultsTitle: String {
        portfolio.filters.query.isEmpty
            ? "Explore the Portfolio"
            : "Results for \"\(portfolio.filters.query)\""
    }
}

// MARK: - Filter sheet

struct FilterSheet: View {
    @Binding var filters: PropertyFilters

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    picker("Borough", selection: $filters.borough, options: session.options("boroughs"))
                    picker("Council", selection: $filters.council, options: session.options("councils"))
                    picker("Region", selection: $filters.region, options: session.options("regions"))
                    picker("Property type", selection: $filters.propertyType, options: session.options("propertyTypes"))
                    picker("Status", selection: $filters.verification, options: VerificationStatus.allCases.map(\.rawValue))
                } header: {
                    Text("Scope")
                } footer: {
                    Text("Every figure on the dashboard and in exports reflects these filters.")
                }

                Section {
                    Button {
                        filters.clearDropdowns()
                    } label: {
                        Label("Show the entire company", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(filters.activeCount == 0)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func picker(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("All").tag("")

            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
    }
}

// MARK: - Account sheet

struct AccountSheet: View {
    let portfolio: PortfolioStore

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var isSigningOut = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            Form {
                if session.isDemo {
                    demoSection
                }

                if let user = session.user {
                    Section {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: user.roleLabel)

                        if let phone = user.phone, !phone.isEmpty {
                            LabeledContent("Phone", value: phone)
                        }
                    } header: {
                        Text("Signed in as")
                    }

                    Section {
                        LabeledContent("Can edit records", value: user.permissions.canEdit ? "Yes" : "No")
                        LabeledContent("Can approve", value: user.permissions.canReview ? "Yes" : "No")
                        LabeledContent("Can add fields", value: user.permissions.canManageFields ? "Yes" : "No")
                    } header: {
                        Text("Permissions")
                    } footer: {
                        Text("Permissions are set by your corporate administrator and enforced by the server.")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        isSigningOut = true
                        Task {
                            await session.signOut()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            if isSigningOut {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(isSigningOut)
                } footer: {
                    if session.isDemo {
                        Text("Signed in to the demo. Sign out to return to the real sign-in screen.")
                    } else if !APIConfiguration.environmentLabel.isEmpty {
                        Text("Connected to \(APIConfiguration.environmentLabel) · \(APIConfiguration.baseURL.host() ?? "")")
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Shown only on a demo account: says plainly that the figures are made up,
    /// and offers the way back to a clean copy of them.
    private var demoSection: some View {
        Section {
            Button {
                isResetting = true

                Task {
                    await session.resetDemoData()
                    await portfolio.reload()
                    isResetting = false
                    dismiss()
                }
            } label: {
                HStack {
                    Label("Reset demo data", systemImage: "arrow.counterclockwise")

                    if isResetting {
                        Spacer()
                        ProgressView().controlSize(.small)
                    }
                }
            }
            .disabled(isResetting)
        } header: {
            Label("Demo mode", systemImage: "play.circle.fill")
        } footer: {
            Text("Every figure here is sample data held on this device. Nothing is sent to a server, and nothing you change is saved anywhere else.")
        }
    }
}
