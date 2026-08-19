import SwiftUI

// MARK: - Card

/// The white rounded panel everything sits on.
struct HubCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: Theme.navy.opacity(0.07), radius: 13, x: 0, y: 5)
    }
}

// MARK: - Status pill

struct StatusPill: View {
    let status: VerificationStatus
    var small = false

    var body: some View {
        HStack(spacing: 5) {
            if status.showsStar {
                Image(systemName: "star.fill")
                    .font(.system(size: small ? 8 : 9))
                    .foregroundStyle(Theme.yellow)
            } else {
                Circle()
                    .fill(status.tint)
                    .frame(width: 6, height: 6)
            }

            Text(status.rawValue)
                .font(Theme.body(small ? 10 : 11, weight: .bold))
                .foregroundStyle(status.tint)
        }
        .padding(.horizontal, small ? 9 : 12)
        .padding(.vertical, small ? 3 : 5)
        .background(Color.white, in: Capsule())
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: Theme.navy.opacity(0.08), radius: 4, y: 2)
        .accessibilityLabel("Verification status: \(status.rawValue)")
    }
}

// MARK: - Chip

struct Chip: View {
    enum Tone {
        case yellow, navy, soft

        var background: Color {
            switch self {
            case .yellow: return Theme.yellow
            case .navy: return Theme.navy
            case .soft: return Theme.lavender
            }
        }

        var foreground: Color {
            switch self {
            case .yellow: return Theme.navyDark
            case .navy: return .white
            case .soft: return Theme.navy
            }
        }
    }

    let text: String
    var tone: Tone = .yellow
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }

            Text(text).font(Theme.body(11, weight: .heavy))
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(tone.background, in: Capsule())
    }
}

// MARK: - Completeness ring

struct CompletenessRing: View {
    let percent: Int
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6
    /// On navy backgrounds the ring is yellow on translucent white.
    var onDark = false

    private var clamped: Double { Double(min(max(percent, 0), 100)) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    onDark ? Color.white.opacity(0.18) : Theme.navy.opacity(0.10),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    onDark ? Theme.yellow : Theme.completenessColor(percent),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: percent)

            Text("\(percent)%")
                .font(Theme.body(size / 4.2, weight: .heavy))
                .foregroundStyle(onDark ? .white : Theme.ink)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(percent) percent complete")
    }
}

// MARK: - Buttons

struct HubButton: View {
    enum Style {
        case primary, amber, yellow, subtle, ghost, white
    }

    let title: String
    var icon: String?
    var style: Style = .primary
    var isCompact = false
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(foreground)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: isCompact ? 11 : 13, weight: .bold))
                }

                Text(title).font(Theme.body(isCompact ? 12 : 13, weight: .heavy))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, isCompact ? 16 : 22)
            .padding(.vertical, isCompact ? 8 : 12)
            .background(background, in: Capsule())
            .overlay {
                if style == .subtle {
                    Capsule().stroke(Theme.navy, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var background: Color {
        switch style {
        case .primary: return Theme.navy
        case .amber: return Theme.amber
        case .yellow: return Theme.yellow
        case .subtle, .white: return .white
        case .ghost: return Theme.navy.opacity(0.07)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .amber, .yellow: return Theme.navyDark
        case .subtle, .ghost, .white: return Theme.navy
        }
    }
}

// MARK: - Section heading

struct SectionHeading<Trailing: View>: View {
    private let title: String
    private let trailing: Trailing

    /// A heading with something on the right — a button, a count, a chip.
    ///
    /// Both initialisers are written out rather than leaning on the synthesised
    /// memberwise one: a generic view with a memberwise init *and* a
    /// constrained-extension init gives the compiler an overload set it cannot
    /// always resolve. Two explicit signatures that differ in arity cannot be
    /// ambiguous.
    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.display(19))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 8)

            trailing
        }
    }
}

extension SectionHeading where Trailing == EmptyView {
    /// A heading on its own.
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - KPI tile

struct KpiTile: View {
    let label: String
    let value: String
    var tone: Color = Theme.ink
    var caption: String?

    var body: some View {
        HubCard(padding: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(Theme.body(9, weight: .heavy))
                    .kerning(0.7)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)

                Text(value)
                    .font(Theme.display(22))
                    .foregroundStyle(tone)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let caption {
                    Text(caption)
                        .font(Theme.body(10))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

// MARK: - Empty and error states

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.amber).frame(width: 62, height: 62)
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Theme.navyDark)
            }
            .shadow(color: Theme.amber.opacity(0.4), radius: 10, y: 5)

            Text(title)
                .font(Theme.display(17))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.body(12))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let actionTitle, let action {
                HubButton(title: actionTitle, style: .amber, isCompact: true, action: action)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

struct InlineErrorView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text(message).font(Theme.body(12, weight: .semibold))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.red)
                }
                .foregroundStyle(Theme.subtleInk)

                if let retry {
                    HubButton(title: "Try again", icon: "arrow.clockwise", style: .subtle, isCompact: true, action: retry)
                }
            }
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(toast.style == .error ? Theme.red : Theme.yellow)

            Text(toast.message)
                .font(Theme.body(12, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.navyDark, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(.horizontal, 24)
    }

    private var icon: String {
        switch toast.style {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

/// Presents the session's toast above whatever is on screen.
struct ToastLayer: ViewModifier {
    @Bindable var session: SessionStore

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = session.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(3.4))
                        withAnimation(.spring(duration: 0.3)) { session.toast = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: session.toast)
    }
}

extension View {
    func toastLayer(_ session: SessionStore) -> some View {
        modifier(ToastLayer(session: session))
    }
}
