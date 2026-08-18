import SwiftUI

/// The directory card: a navy stat panel on the left, the record's identity on
/// the right. Mirrors the service-card layout from the web app.
struct PropertyCard: View {
    let property: PropertySummary
    var showsRing = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statPanel

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text(property.siteName)
                        .font(Theme.display(15))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if property.openFlagCount > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.amber)
                            .accessibilityLabel("\(property.openFlagCount) unconfirmed changes")
                    }
                }

                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.amber)

                    Text(property.address.isEmpty ? "No address recorded" : property.address)
                        .font(Theme.body(11))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .padding(.top, 3)

                HStack(spacing: 6) {
                    Chip(text: property.borough ?? "—")
                    StatusPill(status: property.verification, small: true)
                }
                .padding(.top, 7)

                Spacer(minLength: 8)

                HStack(alignment: .bottom) {
                    Text("by: \(property.managerLabel)")
                        .font(Theme.body(11).italic())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text("\(property.completeness)% complete")
                        .font(Theme.body(11, weight: .heavy))
                        .foregroundStyle(Theme.completenessColor(property.completeness))
                        .layoutPriority(1)
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: Theme.navy.opacity(0.09), radius: 12, y: 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var statPanel: some View {
        VStack(spacing: 3) {
            if showsRing {
                CompletenessRing(percent: property.completeness, size: 54, lineWidth: 6, onDark: true)
            } else {
                Text(property.totalUnits.formattedCount)
                    .font(Theme.display(25))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("TOTAL UNITS")
                    .font(Theme.body(8, weight: .heavy))
                    .kerning(0.9)
                    .foregroundStyle(.white.opacity(0.55))

                HStack(spacing: 5) {
                    Text("\(property.elevatorCount) lifts")
                    Text("·")
                    Text("\(property.floorsLabel) fl")
                }
                .font(Theme.body(9, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
            }
        }
        .frame(width: 104, height: 104)
        .background(Theme.tileGradient, in: RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
    }

    private var accessibilityDescription: String {
        """
        \(property.siteName), \(property.borough ?? "no borough"), \
        \(property.totalUnits) units, \(property.completeness) percent complete, \
        status \(property.verification.rawValue), managed by \(property.managerLabel)
        """
    }
}

/// The compact row used in "Needs attention" and the approvals list.
struct PropertyRow: View {
    let property: PropertySummary
    var showsChevron = true

    var body: some View {
        HStack(spacing: 13) {
            VStack(spacing: 0) {
                Text(property.totalUnits.formattedCount)
                    .font(Theme.display(15))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("UNITS")
                    .font(Theme.body(7, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 52, height: 52)
            .background(Theme.tileGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(property.siteName)
                    .font(Theme.body(13, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Text("by: \(property.managerLabel)")
                    .font(Theme.body(11).italic())
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 5) {
                Chip(text: "\(property.completeness)%")
                StatusPill(status: property.verification, small: true)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(10)
        .background(Theme.lavenderSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
