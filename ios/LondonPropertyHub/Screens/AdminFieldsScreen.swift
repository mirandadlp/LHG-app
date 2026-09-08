import SwiftUI

/// The custom-field builder and the dropdown-list editor. What corporate adds
/// here is collected on every property immediately — no rebuild, no release.
struct AdminFieldsScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.topSafeAreaInset) private var topSafeAreaInset

    @State private var showsNewField = false
    @State private var pendingDeletion: FieldDefinition?
    @State private var listKey = "boroughs"
    @State private var newOption = ""
    @State private var isBusy = false

    private var customFields: [FieldDefinition] {
        session.fields.filter(\.custom)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                VStack(spacing: 16) {
                    customFieldsCard
                    optionListsCard
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .refreshable { await session.refreshRegistry() }
        .sheet(isPresented: $showsNewField) {
            NewFieldSheet()
        }
        .confirmationDialog(
            "Remove \"\(pendingDeletion?.label ?? "")\"?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove field", role: .destructive) {
                if let field = pendingDeletion { delete(field) }
                pendingDeletion = nil
            }

            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Every value recorded against this field on every property is deleted. This cannot be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shape the Record\nAs You Grow")
                .font(Theme.display(26))
                .foregroundStyle(.white)

            Text("Add what the business decides it needs next.")
                .font(Theme.body(11))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .padding(.top, topSafeAreaInset + 24)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(
            UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous)
        )
    }

    // MARK: - Custom fields

    private var customFieldsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Custom Fields") {
                HubButton(title: "Add", icon: "plus", style: .amber, isCompact: true) {
                    showsNewField = true
                }
            }

            if customFields.isEmpty {
                HubCard {
                    EmptyStateView(
                        icon: "slider.horizontal.3",
                        title: "No custom fields yet",
                        message: "Add one and it appears on every property record straight away.",
                        actionTitle: "Create a field",
                        action: { showsNewField = true }
                    )
                }
            } else {
                ForEach(customFields) { field in
                    HubCard(padding: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(field.label)
                                    .font(Theme.body(13, weight: .heavy))
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("\(field.section.label) · \(field.type.rawValue)\(field.required ? " · required" : "")")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.muted)

                                if let help = field.help, !help.isEmpty {
                                    Text(help)
                                        .font(Theme.body(11).italic())
                                        .foregroundStyle(Theme.subtleInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 8)

                            Button {
                                pendingDeletion = field
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.red)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white, in: Circle())
                                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(field.label)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Option lists

    private var optionListsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Dropdown Lists")

            HubCard {
                VStack(alignment: .leading, spacing: 14) {
                    LabelledField("List") {
                        MenuPicker(selection: $listKey, options: session.optionLists, isReadOnly: false)
                    }

                    FlowLayout(spacing: 7) {
                        ForEach(session.options(listKey), id: \.self) { option in
                            HStack(spacing: 6) {
                                Text(option)
                                    .font(Theme.body(11, weight: .bold))
                                    .foregroundStyle(.white)

                                Button {
                                    removeOption(option)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .heavy))
                                        .foregroundStyle(Theme.yellow)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(option)")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.navy, in: Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Add an option", text: $newOption)
                            .font(Theme.body(12))
                            .fieldChrome()
                            .submitLabel(.done)
                            .onSubmit(addOption)

                        HubButton(title: "Add", style: .amber, isCompact: true, isLoading: isBusy) {
                            addOption()
                        }
                    }

                    Text("Removing an option does not change properties that already use it — it only stops it being chosen again.")
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Actions

    private func delete(_ field: FieldDefinition) {
        Task {
            do {
                _ = try await PropertyAPI().deleteField(field)
                await session.refreshRegistry()
                session.show("\"\(field.label)\" removed from the record.", style: .success)
            } catch {
                session.show(error: error)
            }
        }
    }

    private func addOption() {
        let value = newOption.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty, !isBusy else { return }

        isBusy = true

        Task {
            defer { isBusy = false }

            do {
                _ = try await PropertyAPI().addOption(list: listKey, value: value)
                newOption = ""
                await session.refreshRegistry()
            } catch {
                session.show(error: error)
            }
        }
    }

    private func removeOption(_ value: String) {
        Task {
            do {
                _ = try await PropertyAPI().removeOption(list: listKey, value: value)
                await session.refreshRegistry()
            } catch {
                session.show(error: error)
            }
        }
    }
}

// MARK: - New field sheet

struct NewFieldSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var help = ""
    @State private var section = FieldSection.building
    @State private var type = "number"
    @State private var isRequired = false
    @State private var unit = ""
    @State private var optionsText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let types = ["text", "number", "decimal", "date", "yesno", "dropdown", "measurement", "notes"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Number of boilers", text: $label)

                    TextField("Guidance shown to property managers", text: $help, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Field")
                }

                Section {
                    Picker("Section", selection: $section) {
                        ForEach(FieldSection.allCases, id: \.self) { value in
                            Text(value.label).tag(value)
                        }
                    }

                    Picker("Data type", selection: $type) {
                        ForEach(types, id: \.self) { value in
                            Text(value.capitalized).tag(value)
                        }
                    }
                }

                if type == "dropdown" {
                    Section {
                        TextField("Gas, Electric, District", text: $optionsText, axis: .vertical)
                            .lineLimit(1...3)
                    } header: {
                        Text("Options")
                    } footer: {
                        Text("Comma separated. Property managers pick one of these.")
                    }
                }

                if type == "number" || type == "decimal" {
                    Section {
                        TextField("e.g. kW, litres, units", text: $unit)
                    } header: {
                        Text("Measurement unit")
                    }
                }

                Section {
                    Toggle("Required before submitting", isOn: $isRequired)
                } footer: {
                    Text("A required field must be filled in before a property manager can submit their record for review.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.red)
                            .font(Theme.body(12))
                    }
                }
            }
            .navigationTitle("Create a Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil

        let options = optionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task {
            defer { isSaving = false }

            do {
                _ = try await PropertyAPI().createField(
                    PropertyAPI.NewFieldBody(
                        label: label.trimmingCharacters(in: .whitespaces),
                        section: section.rawValue,
                        type: type,
                        required: isRequired,
                        help: help.isEmpty ? nil : help,
                        unit: unit.isEmpty ? nil : unit,
                        optionList: type == "dropdown" ? options : nil
                    )
                )

                await session.refreshRegistry()
                session.show("\"\(label)\" is now collected on every property record.", style: .success)
                dismiss()
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
