import SwiftUI

/// The signed-in shell: a tab per area, filtered to what the role may reach.
struct MainShell: View {
    @Environment(SessionStore.self) private var session

    @State private var portfolio = PortfolioStore()
    @State private var selectedTab: Tab = .home
    @State private var showsFilters = false
    @State private var showsAccount = false

    enum Tab: String, Hashable, CaseIterable {
        case home, properties, explore, approvals, reports, importData, fields

        var label: String {
            switch self {
            case .home: return "Home"
            case .properties: return "Properties"
            case .explore: return "Explore"
            case .approvals: return "Approvals"
            case .reports: return "Reports"
            case .importData: return "Import"
            case .fields: return "Fields"
            }
        }

        var icon: String {
            switch self {
            case .home: return "square.grid.2x2.fill"
            case .properties: return "building.2.fill"
            case .explore: return "magnifyingglass"
            case .approvals: return "checkmark.seal.fill"
            case .reports: return "chart.bar.doc.horizontal.fill"
            case .importData: return "square.and.arrow.up.fill"
            case .fields: return "slider.horizontal.3"
            }
        }
    }

    /// Leadership never sees Approvals; only corporate sees Import and Fields.
    private var availableTabs: [Tab] {
        var tabs: [Tab] = [.home, .properties, .explore]

        if !session.isLeadership { tabs.append(.approvals) }

        tabs.append(.reports)

        if session.canImport { tabs.append(.importData) }
        if session.canManageFields { tabs.append(.fields) }

        return tabs
    }

    var body: some View {
        @Bindable var session = session

        TabView(selection: $selectedTab) {
            ForEach(availableTabs, id: \.self) { tab in
                NavigationStack {
                    screen(for: tab)
                        .background(Theme.lavender.ignoresSafeArea())
                        .navigationDestination(for: PropertyRoute.self) { route in
                            PropertyDetailScreen(propertyID: route.id, portfolio: portfolio)
                        }
                }
                .tabItem {
                    Label(tab.label, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .environment(portfolio)
        .task { await portfolio.loadIfNeeded() }
        .toastLayer(session)
        .sheet(isPresented: $showsFilters) {
            FilterSheet(filters: $portfolio.filters)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAccount) {
            AccountSheet(portfolio: portfolio)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func screen(for tab: Tab) -> some View {
        switch tab {
        case .home:
            DashboardScreen(
                portfolio: portfolio,
                onOpenFilters: { showsFilters = true },
                onOpenAccount: { showsAccount = true },
                onSeeApprovals: { selectedTab = session.isLeadership ? .properties : .approvals }
            )

        case .properties:
            DirectoryScreen(portfolio: portfolio, onOpenFilters: { showsFilters = true })

        case .explore:
            ExploreScreen(portfolio: portfolio, onOpenFilters: { showsFilters = true })

        case .approvals:
            ApprovalsScreen(portfolio: portfolio)

        case .reports:
            ReportsScreen(portfolio: portfolio, onOpenFilters: { showsFilters = true })

        case .importData:
            ImportScreen(portfolio: portfolio)

        case .fields:
            AdminFieldsScreen()
        }
    }
}

// MARK: - Hero header

/// The navy header every main screen wears, with the underline search field
/// and filter button from the web app.
struct HubHeader: View {
    let title: String
    let subtitle: String
    @Binding var searchText: String
    var searchPrompt = "Search here"
    var filterCount: Int = 0
    var onOpenFilters: () -> Void
    var onOpenAccount: (() -> Void)?

    @Environment(SessionStore.self) private var session
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(session.user?.initials ?? "")
                    .font(Theme.body(13, weight: .heavy))
                    .foregroundStyle(Theme.navyDark)
                    .frame(width: 42, height: 42)
                    .background(Theme.amber, in: Circle())
                    .shadow(color: Theme.amber.opacity(0.4), radius: 8, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.user?.name ?? "")
                        .font(Theme.body(13, weight: .heavy))
                        .foregroundStyle(.white)

                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 8))
                        Text("\(session.user?.roleLabel ?? "") · London Portfolio")
                            .font(Theme.body(10))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }

                if session.isDemo {
                    // Sample figures must never be mistaken for real ones, so
                    // the badge stays on screen for the whole demo.
                    Text("DEMO")
                        .font(Theme.body(9, weight: .heavy))
                        .foregroundStyle(Theme.navyDark)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.amber, in: Capsule())
                        .accessibilityLabel("Demo mode, sample data")
                }

                Spacer()

                if let onOpenAccount {
                    Button(action: onOpenAccount) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 19))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Account")
                }
            }

            Text(title)
                .font(Theme.display(26))
                .foregroundStyle(.white)
                .lineSpacing(1)
                .padding(.top, 18)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(Theme.body(11))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))

                TextField("", text: $searchText, prompt: Text(searchPrompt).foregroundStyle(.white.opacity(0.5)))
                    .font(Theme.body(13))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }

                Button(action: onOpenFilters) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(filterCount > 0 ? Theme.yellow : .white.opacity(0.75))

                        if filterCount > 0 {
                            Text("\(filterCount)")
                                .font(Theme.body(8, weight: .heavy))
                                .foregroundStyle(Theme.navyDark)
                                .frame(width: 13, height: 13)
                                .background(Theme.yellow, in: Circle())
                                .offset(x: 7, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(filterCount > 0 ? "Filters, \(filterCount) active" : "Filters")
            }
            .padding(.top, 18)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(height: 1.5)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(
            UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous)
        )
    }
}
