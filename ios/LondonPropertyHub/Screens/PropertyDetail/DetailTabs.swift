import Charts
import SwiftUI

/// A bar in the accommodation-mix chart. Named rather than a tuple so `Chart`
/// can identify each mark by key path.
struct AccommodationBar: Identifiable {
    let label: String
    let count: Int

    var id: String { label }
}

// MARK: - Overview

struct OverviewTab: View {
    let detail: PropertyDetail
    let onShowMissing: () -> Void

    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: 16) {
            HubCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Record Summary").font(Theme.display(15))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        statTile("Total Units", detail.totalUnits.formattedCount, highlighted: true)
                        statTile("Elevators", "\(detail.elevators.count)")
                        statTile("Staircases", "\(detail.staircases.count)")
                        statTile("Floors", detail.values["floors"]?.displayValue ?? "—")
                        statTile("Accessible Beds", "\(detail.values["accessibleBedroomCount"]?.intValue ?? 0)")
                        statTile("Documents", "\(detail.documents.count)")
                    }
                }
            }

            if !accommodationMix.isEmpty {
                HubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accommodation Mix").font(Theme.display(15))

                        Chart(accommodationMix) { entry in
                            BarMark(
                                x: .value("Count", entry.count),
                                y: .value("Type", entry.label)
                            )
                            .foregroundStyle(Theme.navy)
                            .cornerRadius(6)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("\(entry.count)")
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
                        .frame(height: max(140, CGFloat(accommodationMix.count) * 30))
                    }
                }
            }

            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completeness").font(Theme.display(15))

                    HStack(spacing: 16) {
                        CompletenessRing(percent: detail.completeness, size: 66, lineWidth: 8)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(detail.missing.required.count) required outstanding")
                                .font(Theme.body(12, weight: .bold))
                                .foregroundStyle(detail.missing.required.isEmpty ? Theme.green : Theme.red)

                            Text("\(detail.missing.optional.count) optional outstanding")
                                .font(Theme.body(12, weight: .bold))
                                .foregroundStyle(Theme.orange)

                            Button("View missing information", action: onShowMissing)
                                .font(Theme.body(12, weight: .heavy))
                                .foregroundStyle(Theme.navy)
                                .padding(.top, 3)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }

            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Responsibility").font(Theme.display(15))

                    VStack(spacing: 8) {
                        detailRow("Manager", detail.values["manager"]?.displayValue)
                        detailRow("Email", detail.values["managerEmail"]?.displayValue)
                        detailRow("Phone", detail.values["managerPhone"]?.displayValue)
                        detailRow("Ownership", detail.values["ownershipCompany"]?.displayValue)
                        detailRow("Management", detail.values["managementCompany"]?.displayValue)
                        detailRow("Opened", detail.values["openedDate"]?.displayValue)
                    }
                }
            }

            HubCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Changes").font(Theme.display(15))

                    if detail.history.isEmpty {
                        Text("No changes recorded yet.")
                            .font(Theme.body(11))
                            .foregroundStyle(Theme.muted)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(detail.history.prefix(4)) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.field): \(entry.prev) → \(entry.next)")
                                        .font(Theme.body(11, weight: .bold))
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("by: \(entry.by) · \(entry.date ?? "")")
                                        .font(Theme.body(11).italic())
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var accommodationMix: [AccommodationBar] {
        session.accommodationTypes.compactMap { type in
            let count = detail.count(type.key)
            return count > 0 ? AccommodationBar(label: type.label, count: count) : nil
        }
    }

    private func statTile(_ label: String, _ value: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.display(20))
                .foregroundStyle(highlighted ? Theme.yellow : Theme.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(label.uppercased())
                .font(Theme.body(9, weight: .heavy))
                .kerning(0.7)
                .foregroundStyle(highlighted ? .white.opacity(0.6) : Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            highlighted ? AnyShapeStyle(Theme.tileGradient) : AnyShapeStyle(Theme.lavenderSoft),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func detailRow(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)

            Spacer(minLength: 12)

            Text(value?.isEmpty == false ? value! : "—")
                .font(Theme.body(12, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Registry-driven section tab

/// General, Dimensions, Accessibility and Building all render from the field
/// registry, so a custom field appears here the moment corporate adds it.
struct FieldSectionTab: View {
    let store: PropertyStore
    let detail: PropertyDetail
    let section: FieldSection

    @Environment(SessionStore.self) private var session

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(section.label).font(Theme.display(16))

                ForEach(session.fields(in: section)) { field in
                    FieldEditor(
                        field: field,
                        value: store.value(field.key),
                        options: session.options(field.optionListKey),
                        measurementUnits: session.measurementUnits,
                        isReadOnly: !detail.permissions.canEdit,
                        errors: store.errors(for: field.key),
                        onChange: { store.setValue($0, for: field.key) },
                        onCommit: { Task { await store.flushPendingEdits() } }
                    )
                }
            }
        }
    }
}

// MARK: - Accommodation

struct AccommodationTab: View {
    let store: PropertyStore
    let detail: PropertyDetail

    @Environment(SessionStore.self) private var session

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Chip(text: "TOTAL ACCOMMODATION UNITS")

                Text(detail.totalUnits.formattedCount)
                    .font(Theme.display(42))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.top, 8)

                Text("Calculated automatically. Blank counts as zero.")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)

                Divider().overlay(.white.opacity(0.15)).padding(.vertical, 14)

                HStack(spacing: 0) {
                    groupTotal("Rooms", detail.sum(of: session.accommodationKeys(in: "Rooms")))
                    groupTotal("Flats", detail.flatsTotal)
                    groupTotal("Houses", detail.housesTotal)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: Theme.heroRadius, style: .continuous))
            .shadow(color: Theme.navy.opacity(0.25), radius: 16, y: 8)

            ForEach(session.accommodationGroups, id: \.self) { group in
                let types = session.accommodationTypes(in: group)

                if !types.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(group).font(Theme.display(15))

                            ForEach(types) { type in
                                CountStepper(
                                    label: type.label,
                                    value: Binding(
                                        get: { store.count(type.key) },
                                        set: { store.setCount($0, for: type.key) }
                                    ),
                                    isReadOnly: !detail.permissions.canEdit
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func groupTotal(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text(value.formattedCount)
                .font(Theme.display(20))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(label.uppercased())
                .font(Theme.body(9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

/// A count field with steppers either side — quicker than a keyboard when
/// someone is walking a building and adjusting by one or two.
struct CountStepper: View {
    let label: String
    @Binding var value: Int?
    let isReadOnly: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Theme.body(12, weight: .bold))
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                stepButton("minus") {
                    value = max(0, (value ?? 0) - 1)
                }
                .disabled(isReadOnly || (value ?? 0) == 0)

                TextField(
                    "0",
                    text: Binding(
                        get: { value.map(String.init) ?? "" },
                        set: { text in
                            value = text.isEmpty ? nil : max(0, Int(text.filter(\.isNumber)) ?? 0)
                        }
                    )
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.body(15, weight: .heavy))
                .frame(width: 62)
                .padding(.vertical, 8)
                .background(
                    isReadOnly ? Theme.navy.opacity(0.04) : Theme.lavenderSoft,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .disabled(isReadOnly)

                stepButton("plus") {
                    value = (value ?? 0) + 1
                }
                .disabled(isReadOnly)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue("\(value ?? 0)")
        .accessibilityAdjustableAction { direction in
            guard !isReadOnly else { return }

            switch direction {
            case .increment: value = (value ?? 0) + 1
            case .decrement: value = max(0, (value ?? 0) - 1)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.navy)
                .frame(width: 30, height: 30)
                .background(Theme.lavender, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
