import SwiftUI

/// Creating a property captures just enough to open the record; the rest is
/// filled in by the property manager during their verification round.
struct NewPropertySheet: View {
    let portfolio: PortfolioStore

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: FieldValue] = ["operationalStatus": .text("Open")]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [String: [String]] = [:]

    /// The identity of a property — everything else can wait.
    private let keys = [
        "siteName", "propertyName", "addressLine1", "addressLine2", "city",
        "postcode", "borough", "council", "region", "propertyType",
        "manager", "managerEmail", "operationalStatus",
    ]

    private var canSave: Bool {
        !(values["siteName"]?.isEmpty ?? true) && !(values["borough"]?.isEmpty ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("A new record starts empty and unverified. Send a verification request once it is created so the property manager can populate it.")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.body(12, weight: .semibold))
                            .foregroundStyle(Theme.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    ForEach(fields) { field in
                        FieldEditor(
                            field: field,
                            value: values[field.key] ?? .empty,
                            options: session.options(field.optionListKey),
                            measurementUnits: session.measurementUnits,
                            errors: fieldErrors[field.key] ?? [],
                            onChange: { values[field.key] = $0 }
                        )
                    }
                }
                .padding(20)
            }
            .background(Theme.lavender.ignoresSafeArea())
            .navigationTitle("Add a Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView().controlSize(.large).tint(Theme.navy)
                }
            }
        }
    }

    private var fields: [FieldDefinition] {
        keys.compactMap { key in session.fields.first { $0.key == key } }
    }

    private func save() {
        guard canSave, !isSaving else { return }

        isSaving = true
        errorMessage = nil
        fieldErrors = [:]

        Task {
            defer { isSaving = false }

            do {
                let api = PropertyAPI()
                let created = try await api.createProperty(values: values)

                await portfolio.reload()
                session.show("\(created.siteName) added. Send a verification request to populate it.", style: .success)
                dismiss()
            } catch let error as APIError {
                errorMessage = error.errorDescription

                if case .validation(_, let fields) = error {
                    // Server errors arrive keyed "values.siteName"; strip the
                    // prefix so they land under the right control.
                    fieldErrors = Dictionary(
                        uniqueKeysWithValues: fields.map { key, messages in
                            (key.replacingOccurrences(of: "values.", with: ""), messages)
                        }
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
