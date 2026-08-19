import Foundation
import Observation

/// One property record while it is open.
///
/// Edits are optimistic: the field changes on screen straight away, the request
/// goes out, and if it fails the previous value is put back and the reason is
/// shown. Nothing is silently lost.
@MainActor
@Observable
final class PropertyStore {

    private(set) var detail: PropertyDetail?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadError: String?

    /// Per-field validation messages from the server, shown under the field.
    private(set) var fieldErrors: [String: [String]] = [:]

    let propertyID: Int

    private let api: PropertyAPI
    private var pendingSaves: [String: Task<Void, Never>] = [:]

    /// Nonisolated so the detail screen can seed it from `State(initialValue:)`
    /// inside its own nonisolated init.
    nonisolated init(propertyID: Int, api: PropertyAPI = PropertyAPI()) {
        self.propertyID = propertyID
        self.api = api
    }

    // MARK: - Loading

    func load() async {
        isLoading = detail == nil
        loadError = nil

        defer { isLoading = false }

        do {
            detail = try await api.property(id: propertyID)
        } catch {
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Field editing

    /// Read the current value for a field, empty if it has never been set.
    func value(_ key: String) -> FieldValue {
        detail?.values[key] ?? .empty
    }

    /// Save a single field. Debounced so typing a name does not send a request
    /// per character, and coalesced per field so the last value wins.
    func setValue(_ value: FieldValue, for key: String, immediate: Bool = false) {
        guard var current = detail else { return }

        let previous = current.values[key] ?? .empty

        guard previous != value else { return }

        current.values[key] = value
        detail = current
        fieldErrors[key] = nil

        pendingSaves[key]?.cancel()

        pendingSaves[key] = Task { [weak self] in
            guard let self else { return }

            if !immediate {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
            }

            await self.commit(key: key, value: value, previous: previous)
        }
    }

    /// Flush any debounced edit immediately — called when a field loses focus
    /// or the screen is dismissed, so nothing is lost in flight.
    func flushPendingEdits() async {
        let tasks = pendingSaves.values
        for task in tasks {
            _ = await task.value
        }
    }

    private func commit(key: String, value: FieldValue, previous: FieldValue) async {
        isSaving = true
        defer { isSaving = false }

        do {
            detail = try await api.updateProperty(id: propertyID, values: [key: value])
            onChange?(detail)
        } catch let error as APIError {
            // Put the old value back so the screen never shows something the
            // server rejected.
            if var current = detail {
                current.values[key] = previous
                detail = current
            }

            let messages = error.messages(for: key)
            fieldErrors[key] = messages.isEmpty ? [error.errorDescription ?? "That change was not saved."] : messages
            onError?(error)
        } catch {
            onError?(error)
        }
    }

    func errors(for key: String) -> [String] {
        fieldErrors[key] ?? []
    }

    // MARK: - Accommodation

    func count(_ key: String) -> Int? {
        detail?.accommodation[key] ?? nil
    }

    func setCount(_ value: Int?, for key: String) {
        guard var current = detail else { return }

        let previous = current.accommodation[key] ?? nil

        guard previous != value else { return }

        current.accommodation[key] = value
        detail = current

        pendingSaves["accom:\(key)"]?.cancel()

        pendingSaves["accom:\(key)"] = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            self.isSaving = true
            defer { self.isSaving = false }

            do {
                self.detail = try await self.api.updateAccommodation(id: self.propertyID, counts: [key: value])
                self.onChange?(self.detail)
            } catch {
                if var reverted = self.detail {
                    reverted.accommodation[key] = previous
                    self.detail = reverted
                }
                self.onError?(error)
            }
        }
    }

    // MARK: - Workflow

    /// Returns the missing required fields when the server refuses a submit.
    func submit() async -> [PropertyDetail.MissingField]? {
        await flushPendingEdits()

        do {
            detail = try await api.submit(id: propertyID)
            onChange?(detail)
            return nil
        } catch let error as APIError {
            if case .validation = error {
                onError?(error)
                return detail?.missing.required ?? []
            }
            onError?(error)
            return []
        } catch {
            onError?(error)
            return []
        }
    }

    func approve(comment: String?) async {
        await perform { try await self.api.approve(id: self.propertyID, comment: comment) }
    }

    func requestChanges(comment: String?) async {
        await perform { try await self.api.requestChanges(id: self.propertyID, comment: comment) }
    }

    func requestVerification() async {
        await perform { try await self.api.requestVerification(id: self.propertyID) }
    }

    // MARK: - Lifts and stairs

    func addElevator() async {
        do {
            _ = try await api.addElevator(propertyID: propertyID)
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    func update(_ elevator: Elevator) {
        guard var current = detail,
              let index = current.elevators.firstIndex(where: { $0.id == elevator.id })
        else { return }

        current.elevators[index] = elevator
        detail = current

        pendingSaves["lift:\(elevator.id)"]?.cancel()

        pendingSaves["lift:\(elevator.id)"] = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            do {
                _ = try await self.api.updateElevator(propertyID: self.propertyID, elevator: elevator)
            } catch {
                self.onError?(error)
                await self.load()
            }
        }
    }

    func deleteElevator(_ elevator: Elevator) async {
        do {
            _ = try await api.deleteElevator(propertyID: propertyID, elevatorID: elevator.id)
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    func addStaircase() async {
        do {
            _ = try await api.addStaircase(propertyID: propertyID)
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    func update(_ staircase: Staircase) {
        guard var current = detail,
              let index = current.staircases.firstIndex(where: { $0.id == staircase.id })
        else { return }

        current.staircases[index] = staircase
        detail = current

        pendingSaves["stair:\(staircase.id)"]?.cancel()

        pendingSaves["stair:\(staircase.id)"] = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            do {
                _ = try await self.api.updateStaircase(propertyID: self.propertyID, staircase: staircase)
            } catch {
                self.onError?(error)
                await self.load()
            }
        }
    }

    func deleteStaircase(_ staircase: Staircase) async {
        do {
            _ = try await api.deleteStaircase(propertyID: propertyID, staircaseID: staircase.id)
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    // MARK: - Documents

    func uploadDocument(fileURL: URL, type: String, notes: String) async {
        do {
            _ = try await api.uploadDocument(
                propertyID: propertyID,
                fileURL: fileURL,
                type: type,
                notes: notes
            )
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    func deleteDocument(_ document: PropertyDocument) async {
        do {
            _ = try await api.deleteDocument(propertyID: propertyID, documentID: document.id)
            await load()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }

    // MARK: - Change flags

    func resolveFlag(_ flag: ChangeFlag, confirm: Bool) async {
        await perform {
            try await self.api.resolveFlag(propertyID: self.propertyID, flagID: flag.id, confirm: confirm)
        }
    }

    // MARK: - Callbacks

    /// Set by the screen so the portfolio list stays in step with edits here.
    var onChange: ((PropertyDetail?) -> Void)?
    var onError: ((Error) -> Void)?

    private func perform(_ work: @escaping () async throws -> PropertyDetail) async {
        isSaving = true
        defer { isSaving = false }

        do {
            detail = try await work()
            onChange?(detail)
        } catch {
            onError?(error)
        }
    }
}
