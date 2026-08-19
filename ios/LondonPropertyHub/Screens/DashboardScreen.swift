import Charts
import SwiftUI

/// One column of the units-by-type strip. A named type rather than a tuple,
/// because `ForEach` needs a key path for identity and key paths cannot refer
/// to tuple elements.
private struct UnitBreakdown: Identifiable {
    let label: String
    let value: Int

    var id: String { label }

    static func all(from totals: DashboardPayload.Totals) -> [UnitBreakdown] {
        [
            UnitBreakdown(label: "Singles", value: totals.singles),
            UnitBreakdown(label: "Doubles", value: totals.doubles),
            UnitBreakdown(label: "Triples", value: totals.triples),
            UnitBreakdown(label: "Flats", value: totals.flats),
            UnitBreakdown(label: "Houses", value: totals.houses),
        ]
    }
}

struct DashboardScreen: View {
    @Bindable var portfolio: PortfolioStore
    let onOpenFilters: () -> Void
    let onOpenAccount: () -> Void
    let onSeeApprovals: () -> Void

    @Environment(SessionStore.self) private var session

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HubHeader(
                    title: "Best Overview of\nYour Portfolio",
                    subtitle: "We make sure every figure is verified by the expert on the ground",
                    searchText: $portfolio.filters.query,
                    filterCount: portfolio.filters.activeCount,
                    onOpenFilters: onOpenFilters,
                    onOpenAccount: onOpenAccount
                )

                if let dashboard = portfolio.dashboard {
                    content(dashboard)
                        .padding(.horizontal, 20)
                } else if let error = portfolio.loadError {
                    InlineErrorView(message: error) {
                        Task { await portfolio.reload() }
                    }
                    .padding(.horizontal, 20)
                } else {
                    ProgressView()
                        .tint(Theme.navy)
                        .padding(.vertical, 60)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable { await portfolio.reload() }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ dashboard: DashboardPayload) -> some View {
        VStack(spacing: 20) {
            if dashboard.totals.awaiting > 0 {
                awaitingBanner(dashboard.totals.awaiting)
            }

            totalUnitsHero(dashboard.totals)

            if dashboard.filterActive {
                Chip(text: "Filters applied — every figure reflects this selection", icon: "star.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            kpiGrid(dashboard.totals)

            if !dashboard.byBorough.isEmpty {
                unitsByBorough(dashboard.byBorough)
            }

            if !dashboard.byStatus.isEmpty {
                verificationBreakdown(dashboard.byStatus)
            }

            needsAttention(dashboard)
        }
    }

    // MARK: - Banner

    private func awaitingBanner(_ count: Int) -> some View {
        Button(action: onSeeApprovals) {
            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.yellow)

                Text("\(count) \(count == 1 ? "Property" : "Properties") Awaiting Verification")
                    .font(Theme.body(12, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.navyDark)
                    .frame(width: 30, height: 30)
                    .background(Color.white, in: Circle())
            }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background(Theme.navyDark, in: Capsule())
            .shadow(color: Theme.navyDark.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero figure

    private func totalUnitsHero(_ totals: DashboardPayload.Totals) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Chip(text: "TOTAL UNITS")

            Text(totals.units.formattedCount)
                .font(Theme.display(48))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.top, 8)

            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.yellow)

                Text("across \(totals.properties) \(totals.properties == 1 ? "property" : "properties") · sum of every accommodation type")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            Divider().overlay(.white.opacity(0.15)).padding(.vertical, 16)

            HStack(alignment: .top, spacing: 0) {
                ForEach(UnitBreakdown.all(from: totals)) { entry in
                    VStack(spacing: 3) {
                        Text(entry.value.formattedCount)
                            .font(Theme.display(19))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(entry.label.uppercased())
                            .font(Theme.body(9, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.heroRadius, style: .continuous))
        .shadow(color: Theme.navy.opacity(0.3), radius: 18, y: 10)
    }

    // MARK: - KPIs

    private func kpiGrid(_ totals: DashboardPayload.Totals) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            KpiTile(label: "Properties", value: totals.properties.formattedCount)
            KpiTile(label: "WC SC Units", value: totals.wcSc.formattedCount)
            KpiTile(label: "Elevators", value: totals.lifts.formattedCount)
            KpiTile(label: "Accessible Beds", value: totals.accessibleRooms.formattedCount)
            KpiTile(label: "Verified", value: "\(totals.verified) of \(totals.properties)", tone: Theme.green)
            KpiTile(
                label: "Awaiting",
                value: totals.awaiting.formattedCount,
                tone: totals.awaiting > 0 ? Theme.red : Theme.ink
            )
        }
    }

    // MARK: - Charts

    private func unitsByBorough(_ data: [DashboardPayload.BoroughUnits]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Units by Borough")

            HubCard {
                Chart(data) { entry in
                    BarMark(
                        x: .value("Units", entry.units),
                        y: .value("Borough", entry.name)
                    )
                    .foregroundStyle(Theme.navy)
                    .cornerRadius(8)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(entry.units.formattedCount)
                            .font(Theme.body(10, weight: .heavy))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.navy.opacity(0.06))
                        AxisValueLabel().font(Theme.body(10)).foregroundStyle(Theme.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().font(Theme.body(10)).foregroundStyle(Theme.muted)
                    }
                }
                // Enough height per bar that borough names never collide.
                .frame(height: max(160, CGFloat(data.count) * 38))
                .accessibilityLabel("Units by borough")
            }
        }
    }

    private func verificationBreakdown(_ data: [DashboardPayload.StatusCount]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Verification Status")

            HubCard {
                VStack(spacing: 16) {
                    Chart(data) { entry in
                        SectorMark(
                            angle: .value("Properties", entry.value),
                            innerRadius: .ratio(0.62),
                            angularInset: 2
                        )
                        .foregroundStyle(entry.status.chartColor)
                        .cornerRadius(5)
                    }
                    .frame(height: 168)
                    .accessibilityLabel("Verification status breakdown")

                    VStack(spacing: 7) {
                        ForEach(data) { entry in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(entry.status.chartColor)
                                    .frame(width: 8, height: 8)

                                Text(entry.name)
                                    .font(Theme.body(11, weight: .semibold))
                                    .foregroundStyle(Theme.subtleInk)

                                Spacer()

                                Text("\(entry.value)")
                                    .font(Theme.body(11, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Needs attention

    private func needsAttention(_ dashboard: DashboardPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Needs Attention")

            HubCard {
                HStack(spacing: 18) {
                    CompletenessRing(percent: dashboard.totals.avgComplete, size: 74, lineWidth: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Average completeness")
                            .font(Theme.body(12, weight: .bold))
                            .foregroundStyle(Theme.ink)

                        Text("Across \(dashboard.totals.properties) \(dashboard.totals.properties == 1 ? "property" : "properties") in this view.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(attentionSummary(dashboard))
                            .font(Theme.body(11, weight: .heavy))
                            .foregroundStyle(dashboard.needsAttention.isEmpty ? Theme.green : Theme.red)
                            .padding(.top, 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if dashboard.needsAttention.isEmpty {
                HubCard {
                    Text("Every property in this view is verified and complete.")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(dashboard.needsAttention) { property in
                        NavigationLink(value: property) {
                            PropertyRow(property: property)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func attentionSummary(_ dashboard: DashboardPayload) -> String {
        let count = dashboard.needsAttention.count

        return count == 0
            ? "Nothing needs attention."
            : "\(count) \(count == 1 ? "property needs" : "properties need") attention."
    }
}
