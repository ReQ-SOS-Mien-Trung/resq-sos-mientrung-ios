//
//  AppearanceCustomizationView.swift
//  SosMienTrung
//
//  Design System showcase & appearance info
//

import SwiftUI

struct AppearanceCustomizationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Editorial Header
                EditorialPageHeader(
                    title: "Giao Diện",
                    eyebrow: "HỆ THỐNG",
                    subtitle: "Swiss / Neo-Brutalist design system"
                )

                // MARK: - Color Palette
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("MÀU SẮC")
                        .eyebrowStyle()
                        .padding(.horizontal, DS.Spacing.md)

                    VStack(spacing: 0) {
                        colorRow("Accent",  DS.Colors.accent,  "#FF5722")
                        colorRow("Text",  DS.Colors.text,  "Primary")
                        colorRow("Secondary",  DS.Colors.textSecondary,  "Secondary")
                        colorRow("Surface",  DS.Colors.surface,  "Card BG")
                        colorRow("Background",  DS.Colors.background,  "Page BG")
                        colorRow("Border",  DS.Colors.border,  "Stroke")
                        colorRow("Danger",  DS.Colors.danger,  "Error")
                        colorRow("Warning",  DS.Colors.warning,  "Alert")
                        colorRow("Success",  DS.Colors.success,  "OK")
                        colorRow("Info",  DS.Colors.info,  "Link")
                    }
                    .sharpCard()
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.bottom, DS.Spacing.lg)

                // MARK: - Typography
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("TYPOGRAPHY")
                        .eyebrowStyle()
                        .padding(.horizontal, DS.Spacing.md)

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("Mega Title")
                            .font(DS.Typography.largeTitle)
                            .foregroundColor(DS.Colors.text)
                        Text("Page Title")
                            .font(DS.Typography.title)
                            .foregroundColor(DS.Colors.text)
                        Text("Section Header")
                            .font(DS.Typography.title2)
                            .foregroundColor(DS.Colors.text)
                        Text("Card Title")
                            .font(DS.Typography.cardTitle)
                            .foregroundColor(DS.Colors.text)
                        Text("Body")
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text)
                        Text("Caption")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("EYEBROW")
                            .font(DS.Typography.eyebrow)
                            .foregroundColor(DS.Colors.accent)
                    }
                    .sharpCard()
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.bottom, DS.Spacing.lg)

                // MARK: - Components Preview
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("COMPONENTS")
                        .eyebrowStyle()
                        .padding(.horizontal, DS.Spacing.md)

                    // Buttons
                    VStack(spacing: DS.Spacing.sm) {
                        Button("Sharp Button") {}
                            .sharpButton()

                        Button("Outline Button") {}
                            .sharpOutlineButton()
                    }
                    .padding(.horizontal, DS.Spacing.md)

                    // Badge
                    HStack(spacing: DS.Spacing.sm) {
                        ResQBadge(text: "SOS", color: DS.Colors.danger)
                        ResQBadge(text: "ONLINE", color: DS.Colors.success)
                        ResQBadge(text: "3 MỚI", color: DS.Colors.accent)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.bottom, DS.Spacing.lg)

                // MARK: - Spacing Grid
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("SPACING (8PT GRID)")
                        .eyebrowStyle()
                        .padding(.horizontal, DS.Spacing.md)

                    VStack(spacing: DS.Spacing.sm) {
                        spacingRow("xs", DS.Spacing.xs)
                        spacingRow("sm", DS.Spacing.sm)
                        spacingRow("md", DS.Spacing.md)
                        spacingRow("lg", DS.Spacing.lg)
                        spacingRow("xl", DS.Spacing.xl)
                    }
                    .sharpCard()
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Xong") { dismiss() }
                    .font(DS.Typography.body.bold())
                    .foregroundColor(DS.Colors.accent)
            }
        }
    }

    // MARK: - Helpers
    private func colorRow(_ name: String, _ color: Color, _ detail: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Rectangle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Rectangle()
                        .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(DS.Typography.cardTitle)
                    .foregroundColor(DS.Colors.text)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
    }

    private func spacingRow(_ label: String, _ value: CGFloat) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(label)
                .font(DS.Typography.caption.monospaced())
                .foregroundColor(DS.Colors.textSecondary)
                .frame(width: 30, alignment: .trailing)
            Rectangle()
                .fill(DS.Colors.accent)
                .frame(width: value * 4, height: 12)
            Text("\(Int(value))pt")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Color to Hex Extension
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "%02X%02X%02X", r, g, b)
    }
}

#Preview {
    NavigationStack {
        AppearanceCustomizationView()
    }
}
