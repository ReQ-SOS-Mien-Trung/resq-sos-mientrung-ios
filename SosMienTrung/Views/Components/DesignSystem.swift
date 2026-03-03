//
//  DesignSystem.swift
//  SosMienTrung
//
//  ResQ Design System — Swiss Minimal + Sharp Edge
//  Inspired by resq-sos-mientrung-landingpage web design.
//

import SwiftUI

// MARK: - Design Tokens Namespace
enum DS {

    // MARK: - Dark / Battery Saving Check
    /// Returns `true` when battery-saving OR dark theme is active.
    private static var isDarkMode: Bool {
        AppearanceManager.shared.shouldUseDarkColors
    }

    // MARK: - Colors
    enum Colors {
        /// Brand primary — ResQ Orange #FF5722  (dimmed in battery-saving)
        static var accent: Color {
            isDarkMode ? Color(hex: "BF4119") : Color(hex: "FF5722")
        }

        /// Danger / SOS red
        static var danger: Color {
            isDarkMode ? Color(hex: "B03030") : Color(hex: "E53E3E")
        }

        /// Info blue (chat, links)
        static var info: Color {
            isDarkMode ? Color(hex: "0B7EAF") : Color(hex: "0EA5E9")
        }

        /// Success green
        static var success: Color {
            isDarkMode ? Color(hex: "117B38") : Color(hex: "16A34A")
        }

        /// Warning yellow-orange
        static var warning: Color {
            isDarkMode ? Color(hex: "C07E09") : Color(hex: "F59E0B")
        }

        // MARK: Semantic — battery-saving overrides to OLED black
        /// Primary background
        static var background: Color {
            isDarkMode ? Color(hex: "000000") : Color(hex: "FCFCFC")
        }

        /// Grouped / card surface
        static var surface: Color {
            isDarkMode ? Color(hex: "111111") : Color(UIColor.secondarySystemGroupedBackground)
        }

        /// Primary text
        static var text: Color {
            isDarkMode ? .white : Color(UIColor.label)
        }

        /// Secondary text
        static var textSecondary: Color {
            isDarkMode ? Color(hex: "AAAAAA") : Color(UIColor.secondaryLabel)
        }

        /// Muted / tertiary text
        static var textMuted: Color {
            isDarkMode ? Color(hex: "777777") : Color(UIColor.tertiaryLabel)
        }
        static var textTertiary: Color { textMuted }

        /// Divider / separator
        static var divider: Color {
            isDarkMode ? Color(hex: "333333") : Color(UIColor.separator)
        }

        /// Border — strong
        static var border: Color {
            isDarkMode ? Color(hex: "444444") : Color(hex: "D1D5DB")
        }

        /// Border — subtle
        static var borderSubtle: Color {
            isDarkMode ? Color.white.opacity(0.08) : Color(UIColor.label).opacity(0.1)
        }

        /// Overlay / scrim
        static func overlay(_ opacity: Double = 0.5) -> Color {
            Color.black.opacity(opacity)
        }
    }

    // MARK: - Typography
    enum Typography {
        /// Hero / splash — 40pt black
        static let largeTitle: Font = .system(size: 40, weight: .black)
        /// Page title — 28pt heavy
        static let title: Font = .system(size: 28, weight: .heavy)
        /// Section title — 22pt bold
        static let title2: Font = .system(size: 22, weight: .bold)
        /// Card heading — 18pt bold
        static let headline: Font = .system(size: 18, weight: .bold)
        /// Body — 16pt medium
        static let body: Font = .system(size: 16, weight: .medium)
        /// Small body — 14pt regular
        static let subheadline: Font = .system(size: 14, weight: .regular)
        /// Caption — 12pt semibold
        static let cardTitle: Font = .system(size: 16, weight: .bold)
        static let caption: Font = .system(size: 12, weight: .semibold)
        /// Tiny — 10pt bold (eyebrow labels)
        static let eyebrow: Font = .system(size: 10, weight: .bold)
        /// Monospaced — 14pt (numbers, codes)
        static let mono: Font = .system(size: 14, weight: .medium, design: .monospaced)
        /// Monospaced large — 28pt (counters)
        static let monoLarge: Font = .system(size: 28, weight: .bold, design: .monospaced)
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Border Width
    enum Border {
        static let thin: CGFloat = 1
        static let medium: CGFloat = 2
        static let thick: CGFloat = 3
    }

    // MARK: - Corner Radius (sharp by default)
    enum Radius {
        static let none: CGFloat = 0
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        /// Only for image cards / avatars
        static let lg: CGFloat = 10
    }

    // MARK: - Shadow (soft, blur-based)
    enum Shadow {
        static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let small = ShadowStyle(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Shadow Style Helper
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color(hex:) Extension  (canonical location — remove duplicates elsewhere)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

/// Card with subtle border + soft shadow
struct SharpCardModifier: ViewModifier {
    var borderColor: Color = DS.Colors.borderSubtle
    var borderWidth: CGFloat = DS.Border.thin
    var shadow: ShadowStyle = DS.Shadow.medium
    var backgroundColor: Color = DS.Colors.surface
    var radius: CGFloat = DS.Radius.sm

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// Filled button style — no border
struct SharpButtonModifier: ViewModifier {
    var color: Color = DS.Colors.accent
    var textColor: Color = .white
    var borderColor: Color = Color.clear
    var borderWidth: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .font(DS.Typography.headline)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

/// Outline button style — subtle border
struct SharpOutlineButtonModifier: ViewModifier {
    var borderColor: Color = DS.Colors.border
    var textColor: Color = DS.Colors.text

    func body(content: Content) -> some View {
        content
            .font(DS.Typography.headline)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}

/// Eyebrow label — uppercase, tracked, accent color
struct EyebrowModifier: ViewModifier {
    var color: Color = DS.Colors.accent

    func body(content: Content) -> some View {
        content
            .font(DS.Typography.eyebrow)
            .tracking(3)
            .textCase(.uppercase)
            .foregroundColor(color)
    }
}

/// Section header — uppercase caption, bottom rule
struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            content
                .font(DS.Typography.caption)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(DS.Colors.textSecondary)
            Rectangle()
                .fill(DS.Colors.divider)
                .frame(height: DS.Border.thin)
        }
    }
}

/// Editorial divider — thick rule
struct EditorialDivider: View {
    var color: Color = DS.Colors.border
    var height: CGFloat = DS.Border.medium

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: height)
    }
}

// MARK: - View Extensions
extension View {
    /// Apply card styling (subtle border + soft shadow)
    func sharpCard(
        borderColor: Color = DS.Colors.borderSubtle,
        borderWidth: CGFloat = DS.Border.thin,
        shadow: ShadowStyle = DS.Shadow.medium,
        backgroundColor: Color = DS.Colors.surface,
        radius: CGFloat = DS.Radius.sm
    ) -> some View {
        modifier(SharpCardModifier(
            borderColor: borderColor,
            borderWidth: borderWidth,
            shadow: shadow,
            backgroundColor: backgroundColor,
            radius: radius
        ))
    }

    /// Apply sharp filled button styling
    func sharpButton(
        color: Color = DS.Colors.accent,
        textColor: Color = .white,
        borderColor: Color = DS.Colors.border
    ) -> some View {
        modifier(SharpButtonModifier(color: color, textColor: textColor, borderColor: borderColor))
    }

    /// Apply outline button styling
    func sharpOutlineButton(
        borderColor: Color = DS.Colors.border,
        textColor: Color = DS.Colors.text
    ) -> some View {
        modifier(SharpOutlineButtonModifier(borderColor: borderColor, textColor: textColor))
    }

    /// Apply eyebrow label styling
    func eyebrowStyle(color: Color = DS.Colors.accent) -> some View {
        modifier(EyebrowModifier(color: color))
    }

    /// Apply section header styling
    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
}
