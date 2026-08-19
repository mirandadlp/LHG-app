import SwiftUI

// MARK: - Elevators

struct ElevatorsTab: View {
    let store: PropertyStore
    let detail: PropertyDetail

    @Environment(SessionStore.self) private var session
    @State private var pendingDeletion: Elevator?

    private var isReadOnly: Bool { !detail.permissions.canEdit }

    private func addElevator() {
        Task { await store.addElevator() }
    }

    private var emptyState: EmptyStateView {
        let actionTitle: String? = isReadOnly ? nil : "Add an elevator"
        let action: (() -> Void)? = isReadOnly ? nil : addElevator

        return EmptyStateView(
            icon: "arrow.up.arrow.down",
            title: "No elevators recorded",
            message: isReadOnly ? "Nothing has been recorded for this property." : "Add one to start.",
            actionTitle: actionTitle,
            action: action
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            HubCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Number of Elevators: \(detail.elevators.count)")
                            .font(Theme.display(15))

                        Text("A property can have any number of lifts. Add one record per lift.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if !isReadOnly {
                        HubButton(title: "Add", icon: "plus", style: .amber, isCompact: true, action: addElevator)
                    }
                }
            }

            if detail.elevators.isEmpty {
                HubCard { emptyState }
            } else {
                ForEach(detail.elevators.numbered()) { entry in
                    ElevatorCard(
                        elevator: entry.value,
                        number: entry.number,
                        isReadOnly: isReadOnly,
                        elevatorTypes: session.options("elevatorTypes"),
                        onChange: { store.update($0) },
                        onDelete: { pendingDeletion = entry.value }
                    )
                }
            }
        }
        .confirmationDialog(
            "Remove \(pendingDeletion?.displayName ?? "this lift")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let elevator = pendingDeletion {
                    Task { await store.deleteElevator(elevator) }
                }
                pendingDeletion = nil
            }

            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This is recorded in the audit history and cannot be undone from the app.")
        }
    }
}

struct ElevatorCard: View {
    let elevator: Elevator
    let number: Int
    let isReadOnly: Bool
    let elevatorTypes: [String]
    let onChange: (Elevator) -> Void
    let onDelete: () -> Void

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 16) {
                SubRecordHeader(
                    number: number,
                    title: "Elevator",
                    name: elevator.name,
                    isReadOnly: isReadOnly,
                    onDelete: onDelete
                )

                LabelledField("Name / identifier") {
                    TextField("", text: binding(\.name))
                        .font(Theme.body(12))
                        .fieldChrome(isReadOnly: isReadOnly)
                        .disabled(isReadOnly)
                }

                LabelledField("Type") {
                    MenuPicker(
                        selection: binding(\.type),
                        options: elevatorTypes.isEmpty ? ["Passenger", "Service", "Goods", "Platform Lift"] : elevatorTypes,
                        isReadOnly: isReadOnly
                    )
                }

                HStack(spacing: 12) {
                    LabelledField("Capacity") {
                        NumberField(value: binding(\.capacity), isReadOnly: isReadOnly)
                    }

                    LabelledField("Max occupancy") {
                        NumberField(value: binding(\.maxOccupancy), isReadOnly: isReadOnly)
                    }
                }

                HStack(spacing: 12) {
                    LabelledField("Width (m)") {
                        DecimalField(value: binding(\.width), isReadOnly: isReadOnly)
                    }

                    LabelledField("Depth (m)") {
                        DecimalField(value: binding(\.depth), isReadOnly: isReadOnly)
                    }
                }

                HStack(spacing: 12) {
                    LabelledField("Height (m)") {
                        DecimalField(value: binding(\.height), isReadOnly: isReadOnly)
                    }

                    LabelledField("Door width (m)") {
                        DecimalField(value: binding(\.doorWidth), isReadOnly: isReadOnly)
                    }
                }

                LabelledField("Accessible elevator") {
                    YesNoToggle(value: binding(\.accessible), isReadOnly: isReadOnly)
                }

                LabelledField("Service elevator") {
                    YesNoToggle(value: binding(\.service), isReadOnly: isReadOnly)
                }

                LabelledField("Passenger elevator") {
                    YesNoToggle(value: binding(\.passenger), isReadOnly: isReadOnly)
                }

                LabelledField("Notes") {
                    TextField("", text: binding(\.notes), axis: .vertical)
                        .lineLimit(2...5)
                        .font(Theme.body(12))
                        .fieldChrome(isReadOnly: isReadOnly)
                        .disabled(isReadOnly)
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Elevator, Value>) -> Binding<Value> {
        Binding(
            get: { elevator[keyPath: keyPath] },
            set: { newValue in
                var updated = elevator
                updated[keyPath: keyPath] = newValue
                onChange(updated)
            }
        )
    }
}

// MARK: - Staircases

struct StaircasesTab: View {
    let store: PropertyStore
    let detail: PropertyDetail

    @State private var pendingDeletion: Staircase?

    private var isReadOnly: Bool { !detail.permissions.canEdit }

    private func addStaircase() {
        Task { await store.addStaircase() }
    }

    private var emptyState: EmptyStateView {
        let actionTitle: String? = isReadOnly ? nil : "Add a staircase"
        let action: (() -> Void)? = isReadOnly ? nil : addStaircase

        return EmptyStateView(
            icon: "figure.stairs",
            title: "No staircases recorded",
            message: isReadOnly ? "Nothing has been recorded for this property." : "Add one to start.",
            actionTitle: actionTitle,
            action: action
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            HubCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Number of Staircases: \(detail.staircases.count)")
                            .font(Theme.display(15))

                        Text("Add one record per staircase, including emergency stairs.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if !isReadOnly {
                        HubButton(title: "Add", icon: "plus", style: .amber, isCompact: true, action: addStaircase)
                    }
                }
            }

            if detail.staircases.isEmpty {
                HubCard { emptyState }
            } else {
                ForEach(detail.staircases.numbered()) { entry in
                    StaircaseCard(
                        staircase: entry.value,
                        number: entry.number,
                        isReadOnly: isReadOnly,
                        onChange: { store.update($0) },
                        onDelete: { pendingDeletion = entry.value }
                    )
                }
            }
        }
        .confirmationDialog(
            "Remove \(pendingDeletion?.displayName ?? "this staircase")?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let staircase = pendingDeletion {
                    Task { await store.deleteStaircase(staircase) }
                }
                pendingDeletion = nil
            }

            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This is recorded in the audit history and cannot be undone from the app.")
        }
    }
}

struct StaircaseCard: View {
    let staircase: Staircase
    let number: Int
    let isReadOnly: Bool
    let onChange: (Staircase) -> Void
    let onDelete: () -> Void

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 16) {
                SubRecordHeader(
                    number: number,
                    title: "Staircase",
                    name: staircase.name,
                    isReadOnly: isReadOnly,
                    onDelete: onDelete
                )

                LabelledField("Staircase identifier") {
                    TextField("", text: binding(\.name))
                        .font(Theme.body(12))
                        .fieldChrome(isReadOnly: isReadOnly)
                        .disabled(isReadOnly)
                }

                LabelledField("Location") {
                    TextField("", text: binding(\.location))
                        .font(Theme.body(12))
                        .fieldChrome(isReadOnly: isReadOnly)
                        .disabled(isReadOnly)
                }

                HStack(spacing: 12) {
                    LabelledField("Floors served") {
                        NumberField(value: binding(\.floorsServed), isReadOnly: isReadOnly)
                    }

                    LabelledField("Width (m)") {
                        DecimalField(value: binding(\.width), isReadOnly: isReadOnly)
                    }
                }

                LabelledField("Classification") {
                    MenuPicker(
                        selection: binding(\.classification),
                        options: Staircase.classifications,
                        isReadOnly: isReadOnly
                    )
                }

                LabelledField("Emergency exit staircase") {
                    YesNoToggle(value: binding(\.emergencyExit), isReadOnly: isReadOnly)
                }

                LabelledField("Notes") {
                    TextField("", text: binding(\.notes), axis: .vertical)
                        .lineLimit(2...5)
                        .font(Theme.body(12))
                        .fieldChrome(isReadOnly: isReadOnly)
                        .disabled(isReadOnly)
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Staircase, Value>) -> Binding<Value> {
        Binding(
            get: { staircase[keyPath: keyPath] },
            set: { newValue in
                var updated = staircase
                updated[keyPath: keyPath] = newValue
                onChange(updated)
            }
        )
    }
}

// MARK: - Shared sub-record pieces

struct SubRecordHeader: View {
    let number: Int
    let title: String
    let name: String
    let isReadOnly: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(Theme.body(12, weight: .heavy))
                .foregroundStyle(Theme.navyDark)
                .frame(width: 34, height: 34)
                .background(Theme.amber, in: Circle())

            Text(name.isEmpty ? title : "\(title) — \(name)")
                .font(Theme.display(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Spacer(minLength: 4)

            if !isReadOnly {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.red)
                        .frame(width: 32, height: 32)
                        .background(Theme.lavenderSoft, in: Circle())
                        .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title.lowercased())")
            }
        }
    }
}

struct LabelledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.body(11, weight: .bold))
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NumberField: View {
    @Binding var value: Int?
    let isReadOnly: Bool

    var body: some View {
        TextField(
            "",
            text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { text in
                    value = text.isEmpty ? nil : max(0, Int(text.filter(\.isNumber)) ?? 0)
                }
            )
        )
        .keyboardType(.numberPad)
        .font(Theme.body(12))
        .fieldChrome(isReadOnly: isReadOnly)
        .disabled(isReadOnly)
    }
}

struct DecimalField: View {
    @Binding var value: Double?
    let isReadOnly: Bool

    var body: some View {
        TextField(
            "",
            text: Binding(
                get: {
                    guard let value else { return "" }
                    return value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
                },
                set: { text in
                    let cleaned = text.replacingOccurrences(of: ",", with: ".")
                    value = cleaned.isEmpty ? nil : Double(cleaned).map { max(0, $0) }
                }
            )
        )
        .keyboardType(.decimalPad)
        .font(Theme.body(12))
        .fieldChrome(isReadOnly: isReadOnly)
        .disabled(isReadOnly)
    }
}

struct MenuPicker: View {
    @Binding var selection: String
    let options: [String]
    let isReadOnly: Bool

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if selection == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack {
                Text(selection.isEmpty ? "Select…" : selection)
                    .font(Theme.body(12))
                    .foregroundStyle(selection.isEmpty ? Theme.muted : Theme.ink)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .fieldChrome(isReadOnly: isReadOnly)
        }
        .disabled(isReadOnly)
    }
}

struct YesNoToggle: View {
    @Binding var value: TriState
    let isReadOnly: Bool

    var body: some View {
        HStack(spacing: 6) {
            ForEach([TriState.yes, .no], id: \.self) { state in
                let isSelected = value == state

                Button {
                    value = state
                } label: {
                    Text(state.rawValue)
                        .font(Theme.body(11, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Theme.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isSelected ? Theme.navy : Color.white, in: Capsule())
                        .overlay {
                            if !isSelected { Capsule().stroke(Theme.hairline, lineWidth: 1) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isReadOnly)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
        .opacity(isReadOnly ? 0.6 : 1)
    }
}
