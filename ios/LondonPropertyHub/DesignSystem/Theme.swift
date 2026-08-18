import SwiftUI

/// The design tokens from the original web app, carried across unchanged so the
/// iOS app and the web client read as one product.
enum Theme {

    // MARK: - Palette

    /// Primary — hero panels, buttons, navigation.
    static let navy = Color(hex: 0x1E2749)
    /// Deepest — banners and the outer frame.
    static let navyDark = Color(hex: 0x151B36)
    /// The lighter navy that the hero gradients start from.
    static let navyLight = Color(hex: 0x2A3560)
    /// Lavender page canvas.
    static let lavender = Color(hex: 0xE9EBF5)
    /// Lighter panels inside cards.
    static let lavenderSoft = Color(hex: 0xF3F4FA)
    /// Circular category icons.
    static let amber = Color(hex: 0xF5A623)
    /// Value chips.
    static let yellow = Color(hex: 0xF6C244)
    static let ink = Color(hex: 0x1E2749)
    static let muted = Color(hex: 0x8A8FA8)
    static let subtleInk = Color(hex: 0x5C6180)
    static let hairline = Color(hex: 0x1E2749).opacity(0.10)
    static let red = Color(hex: 0xD64545)
    static let orange = Color(hex: 0xDD8A2E)
    static let green = Color(hex: 0x2E9E6B)
    static let inactiveNav = Color(hex: 0xC9CCDD)

    /// The navy gradient used on hero cards and stat panels.
    static let heroGradient = LinearGradient(
        colors: [navyLight, navy, navyDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A shorter two-stop version for small tiles.
    static let tileGradient = LinearGradient(
        colors: [navyLight, navy],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Type

    /// Display face for headlines and figures. Falls back to the system serif
    /// when Lora is not bundled, so text never disappears.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Shape

    static let cardRadius: CGFloat = 24
    static let heroRadius: CGFloat = 28
    static let tileRadius: CGFloat = 18
    static let fieldRadius: CGFloat = 16

    // MARK: - Semantics

    /// Completeness colour: green at 90%+, amber at 70%+, red below.
    static func completenessColor(_ percent: Int) -> Color {
        switch percent {
        case 90...: return green
        case 70...: return amber
        default: return red
        }
    }
}

// MARK: - Verification status styling

extension VerificationStatus {
    var tint: Color {
        switch self {
        case .notStarted: return Color(hex: 0x6E7288)
        case .inProgress: return Theme.orange
        case .submitted: return Color(hex: 0x3B6FB5)
        case .changesRequested: return Color(hex: 0xC0622D)
        case .verified: return Theme.green
        case .overdue: return Theme.red
        case .needsReview: return Color(hex: 0x8256B0)
        }
    }

    /// Verified is the only status that earns a star rather than a dot.
    var showsStar: Bool { self == .verified }

    /// Colour used for this status in charts.
    var chartColor: Color {
        self == .notStarted ? Color(hex: 0x9CA1B8) : tint
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension Int {
    /// Thousands-separated, British style — 1,243 rather than 1243.
    var formattedCount: String {
        Self.countFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_GB")
        return formatter
    }()
}
