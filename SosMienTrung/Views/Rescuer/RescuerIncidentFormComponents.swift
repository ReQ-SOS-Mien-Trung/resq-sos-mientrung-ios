import SwiftUI
import CoreLocation
import UIKit

struct IncidentFormSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }
}

struct IncidentContextRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.Colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct IncidentChoiceChip: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var tone: Color = DS.Colors.accent
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? .white : DS.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.88) : DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? tone : DS.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? tone : DS.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct IncidentBooleanField: View {
    let title: String
    var subtitle: String? = nil
    @Binding var value: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            HStack(spacing: DS.Spacing.xs) {
                IncidentChoiceChip(
                    title: "Có",
                    isSelected: value == true,
                    tone: DS.Colors.success
                ) {
                    value = true
                }

                IncidentChoiceChip(
                    title: "Không",
                    isSelected: value == false,
                    tone: DS.Colors.textSecondary
                ) {
                    value = false
                }
            }
        }
    }
}

struct IncidentTextInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            TextField(placeholder, text: $text, axis: axis)
                .textInputAutocapitalization(.sentences)
                .keyboardType(keyboardType)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
        }
    }
}

struct IncidentLocationSummaryCard: View {
    let coordinate: CLLocationCoordinate2D?

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "location.fill")
                .foregroundColor(coordinate == nil ? DS.Colors.textTertiary : DS.Colors.success)

            if let coordinate {
                Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                    .font(DS.Typography.body.monospacedDigit())
                    .foregroundColor(DS.Colors.text)
            } else {
                Text("Đang lấy vị trí...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }
}

struct IncidentInlineNotice: View {
    let icon: String
    let text: String
    var tone: Color = DS.Colors.info

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(tone)
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.sm)
        .background(tone.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tone.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct IncidentSubmitButton: View {
    let title: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(isEnabled ? DS.Colors.accent : DS.Colors.textTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false || isLoading)
    }
}
