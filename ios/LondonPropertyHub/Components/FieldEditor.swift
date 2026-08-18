import SwiftUI

/// Renders and edits any field in the registry, including custom fields the
/// business added after this build shipped. The field's `type` decides the
/// control — nothing here is hardcoded per field.
struct FieldEditor: View {
    let field: FieldDefinition
    let value: FieldValue
    let options: [String]
    let measurementUnits: [String]
    var isReadOnly = false
    var errors: [String] = []
    let onChange: (FieldValue) -> Void
    /// Called when editing finishes, so the store can flush without waiting
    /// out the debounce.
    var onCommit: () -> Void = {}

    @State private var showsHelp = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            label

            if showsHelp, let help = field.help {
                Text(help)
                    .font(Theme.body(11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8A6A10))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            control

            if let unit = field.unit, !unit.isEmpty {
                Text("Recorded in \(unit)")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.muted)
            }

            if !errors.isEmpty {
                ForEach(errors, id: \.self) { message in
                    Text(message)
                        .font(Theme.body(11, weight: .semibold))
                        .foregroundStyle(Theme.red)
                }
            } else if field.required, value.isEmpty, !isReadOnly {
                Text("Complete this before submitting.")
                    .font(Theme.body(11, weight: .semibold))
                    .foregroundStyle(Theme.red)
            }

            if field.custom {
                Label("CUSTOM FIELD", systemImage: "star.fill")
                    .font(Theme.body(9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundStyle(Color(hex: 0x8A6A10))
            }
        }
    }

    // MARK: - Label

    private var label: some View {
        HStack(spacing: 5) {
            Text(field.label)
                .font(Theme.body(12, weight: .bold))
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)

            if field.required {
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Theme.amber)
                    .accessibilityLabel("Required")
            }

            if field.help != nil {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { showsHelp.toggle() }
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsHelp ? "Hide guidance" : "Show guidance")
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var control: some View {
        switch field.type {
        case .yesno:
            triStateControl

        case .select, .customSelect:
            selectControl

        case .measurement:
            measurementControl

        case .notes:
            notesControl

        case .number, .decimal:
            numberControl

        case .date:
            dateControl

        default:
            textControl
        }
    }

    private var triStateControl: some View {
        HStack(spacing: 6) {
            ForEach(TriState.allCases, id: \.self) { state in
                let isSelected = value.triState == state

                Button {
                    onChange(.text(state.rawValue))
                    onCommit()
                } label: {
                    Text(state.rawValue)
                        .font(Theme.body(12, weight: .bold))
                        .foregroundStyle(isSelected ? .white : Theme.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(isSelected ? Theme.navy : Color.white, in: Capsule())
                        .overlay {
                            if !isSelected { Capsule().stroke(Theme.hairline, lineWidth: 1) }
                        }
                        .shadow(color: isSelected ? Theme.navy.opacity(0.28) : .clear, radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isReadOnly)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }

            Spacer(minLength: 0)
        }
        .opacity(isReadOnly ? 0.6 : 1)
    }

    private var selectControl: some View {
        let choices = field.type == .customSelect ? (field.optionList ?? []) : options

        return Menu {
            Button("Clear") { onChange(.empty); onCommit() }

            Divider()

            ForEach(choices, id: \.self) { choice in
                Button {
                    onChange(.text(choice))
                    onCommit()
                } label: {
                    if value.stringValue == choice {
                        Label(choice, systemImage: "checkmark")
                    } else {
                        Text(choice)
                    }
                }
            }
        } label: {
            HStack {
                Text(value.isEmpty ? "Select…" : value.stringValue)
                    .font(Theme.body(13))
                    .foregroundStyle(value.isEmpty ? Theme.muted : Theme.ink)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .fieldChrome(isReadOnly: isReadOnly)
        }
        .disabled(isReadOnly || choices.isEmpty)
    }

    private var measurementControl: some View {
        HStack(spacing: 8) {
            TextField(
                "0.0",
                text: Binding(
                    get: {
                        guard case .measurement(let magnitude, _) = value, let magnitude else {
                            return value.doubleValue.map { formatted($0) } ?? ""
                        }
                        return formatted(magnitude)
                    },
                    set: { text in
                        let unit = value.measurementUnit
                        let trimmed = text.replacingOccurrences(of: ",", with: ".")
                        onChange(.measurement(value: Double(trimmed), unit: unit))
                    }
                )
            )
            .keyboardType(.decimalPad)
            .font(Theme.body(13))
            .focused($isFocused)
            .fieldChrome(isReadOnly: isReadOnly)
            .disabled(isReadOnly)

            Menu {
                ForEach(measurementUnits, id: \.self) { unit in
                    Button(unit) {
                        onChange(.measurement(value: value.doubleValue, unit: unit))
                        onCommit()
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(value.measurementUnit).font(Theme.body(13, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(Theme.ink)
                .frame(width: 74)
                .fieldChrome(isReadOnly: isReadOnly)
            }
            .disabled(isReadOnly)
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { onCommit() }
        }
    }

    private var notesControl: some View {
        TextField("", text: textBinding, axis: .vertical)
            .lineLimit(3...8)
            .font(Theme.body(13))
            .focused($isFocused)
            .fieldChrome(isReadOnly: isReadOnly)
            .disabled(isReadOnly)
            .onChange(of: isFocused) { _, focused in
                if !focused { onCommit() }
            }
    }

    private var numberControl: some View {
        TextField(
            "",
            text: Binding(
                get: {
                    guard let number = value.doubleValue else { return "" }
                    return field.type == .number ? String(Int(number)) : formatted(number)
                },
                set: { text in
                    let cleaned = text.replacingOccurrences(of: ",", with: ".")
                    if cleaned.isEmpty {
                        onChange(.empty)
                    } else if let number = Double(cleaned) {
                        onChange(.number(max(0, number)))
                    }
                }
            )
        )
        .keyboardType(field.type == .number ? .numberPad : .decimalPad)
        .font(Theme.body(13))
        .focused($isFocused)
        .fieldChrome(isReadOnly: isReadOnly)
        .disabled(isReadOnly)
        .onChange(of: isFocused) { _, focused in
            if !focused { onCommit() }
        }
    }

    private var dateControl: some View {
        HStack {
            DatePicker(
                "",
                selection: Binding(
                    get: { Self.dateFormatter.date(from: value.stringValue) ?? Date() },
                    set: { onChange(.text(Self.dateFormatter.string(from: $0))); onCommit() }
                ),
                displayedComponents: .date
            )
            .labelsHidden()
            .disabled(isReadOnly)

            Spacer()

            if !value.isEmpty, !isReadOnly {
                Button("Clear") { onChange(.empty); onCommit() }
                    .font(Theme.body(11, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .fieldChrome(isReadOnly: isReadOnly)
    }

    private var textControl: some View {
        TextField("", text: textBinding)
            .font(Theme.body(13))
            .keyboardType(keyboardType)
            .textContentType(field.type == .email ? .emailAddress : nil)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(field.type == .email || field.type == .postcode)
            .focused($isFocused)
            .fieldChrome(isReadOnly: isReadOnly)
            .disabled(isReadOnly)
            .onChange(of: isFocused) { _, focused in
                if !focused { onCommit() }
            }
    }

    // MARK: - Helpers

    private var textBinding: Binding<String> {
        Binding(
            get: { value.stringValue },
            set: { onChange($0.isEmpty ? .empty : .text($0)) }
        )
    }

    private var keyboardType: UIKeyboardType {
        switch field.type {
        case .email: return .emailAddress
        case .postcode: return .asciiCapable
        default: return .default
        }
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch field.type {
        case .email: return .never
        case .postcode: return .characters
        default: return .sentences
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%g", value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()
}

// MARK: - Field chrome

private struct FieldChrome: ViewModifier {
    let isReadOnly: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isReadOnly ? Theme.navy.opacity(0.04) : Theme.lavenderSoft,
                in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous)
                    .stroke(isReadOnly ? .clear : Theme.hairline, lineWidth: 1)
            )
            .foregroundStyle(isReadOnly ? Theme.muted : Theme.ink)
    }
}

extension View {
    func fieldChrome(isReadOnly: Bool = false) -> some View {
        modifier(FieldChrome(isReadOnly: isReadOnly))
    }
}
