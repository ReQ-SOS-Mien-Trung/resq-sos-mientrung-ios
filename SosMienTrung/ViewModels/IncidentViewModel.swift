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
        request: MissionIncidentReportRequest
    ) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let response = try await IncidentService.shared.reportMissionTeamIncident(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    request: request
                )
                if request.rescueRequest != nil {
                    if let assistanceId = response.assistanceSosRequestId {
                        successMessage = "Đã báo sự cố mission và tạo yêu cầu giải cứu #\(assistanceId)"
                    } else {
                        successMessage = "Đã báo sự cố mission và gửi kèm yêu cầu giải cứu team"
                    }
                } else if request.handover != nil {
                    successMessage = "Đã báo sự cố mission và gửi thông tin bàn giao"
                } else {
                    successMessage = "Đã báo sự cố mission cho toàn đội"
                }
            } catch {
                errorMessage = "Báo cáo thất bại: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }

    func reportActivityIncident(
        missionId: Int,
        missionTeamId: Int,
        request: ActivityIncidentReportRequest
    ) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await IncidentService.shared.reportTeamActivityIncident(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    request: request
                )
                successMessage = request.supportRequest != nil
                    ? "Đã báo sự cố activity và gửi kèm yêu cầu hỗ trợ"
                    : "Đã báo sự cố activity"
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
