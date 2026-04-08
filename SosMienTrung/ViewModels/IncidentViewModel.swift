import Foundation
import Combine

@MainActor
final class IncidentViewModel: ObservableObject {
    @Published var incidents: [Incident] = []
    @Published var isSubmitting = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func reportMissionIncident(
        missionId: Int,
        missionTeamId: Int,
        description: String,
        lat: Double,
        lng: Double,
        needsRescueAssistance: Bool,
        assistanceSos: IncidentAssistanceSosRequestData?
    ) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let req = ReportMissionTeamIncidentRequest(
                    description: description,
                    latitude: lat,
                    longitude: lng,
                    needsRescueAssistance: needsRescueAssistance,
                    assistanceSos: assistanceSos
                )
                let response = try await IncidentService.shared.reportMissionTeamIncident(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    request: req
                )
                if let assistanceId = response.assistanceSosRequestId {
                    successMessage = "Đã báo sự cố và tạo yêu cầu hỗ trợ SOS #\(assistanceId)"
                } else {
                    successMessage = "Đã báo sự cố cho toàn đội trong nhiệm vụ"
                }
            } catch {
                errorMessage = "Báo cáo thất bại: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    func reportActivityIncident(missionId: Int, activityId: Int, description: String, lat: Double, lng: Double) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let req = ReportMissionActivityIncidentRequest(
                    description: description,
                    latitude: lat,
                    longitude: lng
                )
                _ = try await IncidentService.shared.reportMissionActivityIncident(
                    missionId: missionId,
                    activityId: activityId,
                    request: req
                )
                successMessage = "Đã báo sự cố cho hoạt động"
            } catch {
                errorMessage = "Báo cáo thất bại: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    func loadIncidents(missionId: Int) {
        isLoading = true
        Task {
            do {
                incidents = try await IncidentService.shared.getIncidents(missionId: missionId)
                    .sorted { lhs, rhs in
                        IncidentViewModel.serverDate(from: lhs.reportedAt) > IncidentViewModel.serverDate(from: rhs.reportedAt)
                    }
            } catch {
                print("[IncidentVM] loadIncidents error: \(error)")
            }
            isLoading = false
        }
    }

    func updateStatus(incidentId: Int, status: String, hasInjuredMember: Bool? = nil) {
        Task {
            do {
                let req = UpdateIncidentStatusRequest(
                    status: status,
                    hasInjuredMember: hasInjuredMember
                )
                try await IncidentService.shared.updateIncidentStatus(incidentId: incidentId, request: req)
                successMessage = "Đã cập nhật trạng thái sự cố"
            } catch {
                errorMessage = "Cập nhật sự cố thất bại: \(error.localizedDescription)"
            }
        }
    }

    private static func serverDate(from raw: String?) -> Date {
        guard let raw else { return .distantPast }

        let fullFormatter = ISO8601DateFormatter()
        fullFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]

        return fullFormatter.date(from: raw) ?? basicFormatter.date(from: raw) ?? .distantPast
    }
}
