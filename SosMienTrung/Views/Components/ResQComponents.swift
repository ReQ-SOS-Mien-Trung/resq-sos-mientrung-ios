//
//  ResQComponents.swift
//  SosMienTrung
//
//  Shared UI components — ResQ Design System
//

import SwiftUI

// MARK: - Editorial Page Header
/// Large page title with bottom rule — used at top of every screen
struct EditorialPageHeader: View {
    let title: String
    var eyebrow: String? = nil
    var subtitle: String? = nil
    var trailingContent: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if let eyebrow {
                Text(eyebrow)
                    .eyebrowStyle()
            }

            HStack(alignment: .bottom) {
                Text(title)
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text)

                Spacer()

                if let trailing = trailingContent {
                    trailing
                }
            }

            if let subtitle {
                Text(subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            EditorialDivider(height: DS.Border.thick)
        }
    }
}

// MARK: - Sharp Card Container
struct SharpCardView<Content: View>: View {
    var borderColor: Color = DS.Colors.border
    var backgroundColor: Color = DS.Colors.surface
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(DS.Spacing.md)
            .sharpCard(borderColor: borderColor, backgroundColor: backgroundColor)
    }
}

// MARK: - ResQ Grid Button (Home screen)
struct ResQGridButton: View {
    let icon: String
    let title: String
    var accentColor: Color = DS.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xs) {
                // Icon — square, sharp
                ZStack {
                    Rectangle()
                        .fill(accentColor.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(Rectangle().stroke(accentColor.opacity(0.3), lineWidth: DS.Border.thin))

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(accentColor)
                }

                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .sharpCard(
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.small,
                backgroundColor: DS.Colors.background
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ResQ Badge
struct ResQBadge: View {
    let text: String
    var color: Color = DS.Colors.accent
    var textColor: Color = .white

    var body: some View {
        Text(text)
            .font(DS.Typography.eyebrow)
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxxs)
            .background(color)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
    }
}

// MARK: - ResQ Text Field
struct ResQTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(width: 20)
            }

            TextField(placeholder, text: $text)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.text)
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.background)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
    }
}

// MARK: - ResQ List Row
struct ResQListRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            leading()

            VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.vertical, DS.Spacing.sm)
        .overlay(alignment: .bottom) {
            EditorialDivider(color: DS.Colors.borderSubtle, height: DS.Border.thin)
        }
    }
}

// MARK: - Eyebrow Label View
struct EyebrowLabel: View {
    let text: String
    var color: Color = DS.Colors.accent
    var bordered: Bool = true

    var body: some View {
        Text(text)
            .eyebrowStyle(color: color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .overlay {
                if bordered {
                    Rectangle().stroke(color.opacity(0.3), lineWidth: DS.Border.thin)
                }
            }
    }
}

// MARK: - Stat Card
struct ResQStatCard: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = DS.Colors.accent

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(value)
                .font(DS.Typography.monoLarge)
                .foregroundColor(DS.Colors.text)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .sharpCard(
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.small,
            backgroundColor: DS.Colors.background
        )
    }
}

// MARK: - Message Bubble (Chat)
struct ResQMessageBubble: View {
    let text: String
    let isFromMe: Bool
    var timestamp: String? = nil

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: DS.Spacing.xxs) {
                Text(text)
                    .font(DS.Typography.body)
                    .foregroundColor(isFromMe ? .white : DS.Colors.text)

                if let timestamp {
                    Text(timestamp)
                        .font(DS.Typography.caption)
                        .foregroundColor(isFromMe ? .white.opacity(0.7) : DS.Colors.textMuted)
                }
            }
            .padding(DS.Spacing.sm)
            .background(isFromMe ? DS.Colors.info : DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
            )

            if !isFromMe { Spacer(minLength: 60) }
        }
    }
}
