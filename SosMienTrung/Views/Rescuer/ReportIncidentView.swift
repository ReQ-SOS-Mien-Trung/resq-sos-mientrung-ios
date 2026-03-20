import SwiftUI
import CoreLocation

struct ReportIncidentView: View {
    let missionTeamId: Int
    @ObservedObject var incidentVM: IncidentViewModel
    let missionId: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var description = ""
    @FocusState private var isDescriptionFocused: Bool

    private var currentLocation: CLLocationCoordinate2D? {
        locationManager.currentLocation?.coordinate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DS.Colors.accent)
                                .font(.system(size: 24))
                            VStack(alignment: .leading) {
                                EyebrowLabel(text: "BÁO SỰ CỐ")
                                Text("Ghi nhận sự cố trong nhiệm vụ")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        EditorialDivider(height: DS.Border.thin)
                    }

                    // Location
                    locationSection

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("MÔ TẢ SỰ CỐ")
                            .font(DS.Typography.caption).tracking(1)
                            .foregroundColor(DS.Colors.textSecondary)

                        TextEditor(text: $description)
                            .foregroundColor(DS.Colors.text)
                            .scrollContentBackground(.hidden)
                            .background(DS.Colors.surface)
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(DS.Spacing.sm)
                            .overlay(Rectangle().stroke(
                                description.isEmpty ? DS.Colors.border : DS.Colors.warning,
                                lineWidth: DS.Border.medium
                            ))
                            .focused($isDescriptionFocused)
                            .onChange(of: description) { val in
                                if val.count > 500 { description = String(val.prefix(500)) }
                            }

                        Text("\(description.count)/500 ký tự")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }

                    // Submit
                    Button { submitIncident() } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if incidentVM.isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            Text("GỬI BÁO CÁO")
                                .font(DS.Typography.headline).tracking(2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(isFormValid && !incidentVM.isSubmitting ? DS.Colors.accent : DS.Colors.textTertiary)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                        .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                    }
                    .disabled(!isFormValid || incidentVM.isSubmitting)

                    Spacer()
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Báo Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .foregroundColor(DS.Colors.accent)
                }
            }
            .alert("Lỗi", isPresented: Binding(
                get: { incidentVM.errorMessage != nil },
                set: { if !$0 { incidentVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { incidentVM.errorMessage = nil }
            } message: {
                Text(incidentVM.errorMessage ?? "")
            }
            .onChange(of: incidentVM.successMessage) { msg in
                if msg != nil {
                    incidentVM.loadIncidents(missionId: missionId)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Location Section
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("VỊ TRÍ HIỆN TẠI")
                .font(DS.Typography.caption).tracking(1)
                .foregroundColor(DS.Colors.textSecondary)

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "location.fill")
                    .foregroundColor(currentLocation != nil ? DS.Colors.success : DS.Colors.textTertiary)

                if let loc = currentLocation {
                    Text(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))
                        .font(DS.Typography.body.monospacedDigit())
                        .foregroundColor(DS.Colors.text)
                } else {
                    Text("Đang lấy vị trí...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        }
    }

    // MARK: - Helpers
    private var isFormValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && currentLocation != nil
    }

    private func submitIncident() {
        guard let loc = currentLocation else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        incidentVM.report(
            missionTeamId: missionTeamId,
            description: trimmed,
            lat: loc.latitude,
            lng: loc.longitude
        )
    }
}
