import SwiftUI

struct DirectoryScreen: View {
    @Bindable var portfolio: PortfolioStore
    let onOpenFilters: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var showsNewProperty = false

    private func clearFilters() {
        portfolio.filters.clear()
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
                    SectionHeading(title: "All Properties") {
                        if session.canCreateProperties {
                            HubButton(title: "Add", icon: "plus", style: .amber, isCompact: true) {
                                showsNewProperty = true
                            }
                        }
                    }

                    if portfolio.isLoading, portfolio.properties.isEmpty {
                        ProgressView().tint(Theme.navy).padding(.vertical, 50)
                    } else if let error = portfolio.loadError, portfolio.properties.isEmpty {
                        InlineErrorView(message: error) {
                            Task { await portfolio.reload() }
                        }
                    } else if portfolio.properties.isEmpty {
                        HubCard {
                            EmptyStateView(
                                icon: "building.2",
                                title: "No properties match",
                                message: portfolio.filters.isActive
                                    ? "Nothing matches these filters. Reset the scope to see the whole company."
                                    : "There are no properties in your portfolio yet.",
                                actionTitle: portfolio.filters.isActive ? "Clear filters" : nil,
                                action: portfolio.filters.isActive ? clearFilters : nil
                            )
                        }
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(portfolio.properties) { property in
                                NavigationLink(value: property) {
                                    PropertyCard(property: property)
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
                    SectionHeading(title: resultsTitle) {
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
                                NavigationLink(value: property) {
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
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            Form {
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
                    if !APIConfiguration.environmentLabel.isEmpty {
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
}
