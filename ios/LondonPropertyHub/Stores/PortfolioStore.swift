import Foundation
import Observation

/// The portfolio list and dashboard, plus the filter scope every screen shares.
@MainActor
@Observable
final class PortfolioStore {

    private(set) var properties: [PropertySummary] = []
    private(set) var dashboard: DashboardPayload?
    private(set) var isLoading = false
    private(set) var loadError: String?

    /// Changing this reloads both the list and the dashboard, which is what
    /// keeps every figure on screen consistent with the current selection.
    var filters = PropertyFilters() {
        didSet {
            guard filters != oldValue else { return }
            scheduleReload()
        }
    }

    private let api: PropertyAPI
    private var reloadTask: Task<Void, Never>?

    /// Nonisolated so SwiftUI can build one as a `@State` default value,
    /// which is evaluated outside the main actor. Assigning stored properties
    /// during initialisation is allowed from a nonisolated init.
    nonisolated init(api: PropertyAPI = PropertyAPI()) {
        self.api = api
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard properties.isEmpty, dashboard == nil else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        loadError = nil

        defer { isLoading = false }

        do {
            // The list and the dashboard are independent — fetch together.
            async let list = api.properties(filters: filters)
            async let summary = api.dashboard(filters: filters)

            properties = try await list
            dashboard = try await summary
        } catch is CancellationError {
            // A newer keystroke superseded this load; leave what is on screen.
        } catch {
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Debounced so typing in the search field does not fire a request per key.
    private func scheduleReload() {
        reloadTask?.cancel()

        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))

            guard !Task.isCancelled else { return }

            await self?.reload()
        }
    }

    // MARK: - Local updates

    /// Fold a freshly saved record back into the list without a round trip.
    func apply(_ detail: PropertyDetail) {
        guard let index = properties.firstIndex(where: { $0.id == detail.id }) else {
            Task { await reload() }
            return
        }

        let existing = properties[index]

        properties[index] = PropertySummary(
            id: detail.id,
            publicId: detail.publicId,
            siteName: detail.siteName,
            propertyName: detail.values["propertyName"]?.stringValue,
            address: detail.fullAddress,
            borough: detail.values["borough"]?.stringValue,
            council: detail.values["council"]?.stringValue,
            region: detail.values["region"]?.stringValue,
            propertyType: detail.values["propertyType"]?.stringValue,
            operationalStatus: detail.values["operationalStatus"]?.stringValue,
            manager: detail.values["manager"]?.stringValue,
            managerEmail: detail.values["managerEmail"]?.stringValue,
            verification: detail.verification,
            totalUnits: detail.totalUnits,
            elevatorCount: detail.elevators.count,
            staircaseCount: detail.staircases.count,
            documentCount: detail.documents.count,
            floors: detail.values["floors"]?.intValue,
            accessibleBedroomCount: detail.values["accessibleBedroomCount"]?.intValue,
            stepFree: detail.values["stepFree"]?.stringValue,
            completeness: detail.completeness,
            openFlagCount: detail.flags.count,
            lastUpdated: detail.history.first?.date ?? existing.lastUpdated,
            updatedAt: existing.updatedAt
        )

        // Totals shift when accommodation or status changes, so refresh them.
        Task { await refreshDashboardOnly() }
    }

    func remove(id: Int) {
        properties.removeAll { $0.id == id }
        Task { await refreshDashboardOnly() }
    }

    private func refreshDashboardOnly() async {
        dashboard = try? await api.dashboard(filters: filters)
    }

    // MARK: - Derived

    /// Submitted records, oldest first — the approvals queue.
    var awaitingReview: [PropertySummary] {
        properties.filter { $0.verification == .submitted }
    }

    var otherRounds: [PropertySummary] {
        properties.filter { $0.verification != .submitted }
    }

    var totalUnits: Int {
        dashboard?.totals.units ?? properties.reduce(0) { $0 + $1.totalUnits }
    }

    var awaitingCount: Int {
        dashboard?.totals.awaiting ?? properties.filter { $0.verification != .verified }.count
    }
}
