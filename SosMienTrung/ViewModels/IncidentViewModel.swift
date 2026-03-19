import Foundation
import Combine

@MainActor
final class IncidentViewModel: ObservableObject {
    @Published var incidents: [Incident] = []
    @Published var isSubmitting = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func report(missionTeamId: Int, description: String, lat: Double, lng: Double) {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let req = ReportIncidentRequest(
                    missionTeamId: missionTeamId,
                    description: description,
                    latitude: lat,
                    longitude: lng
                )
                _ = try await IncidentService.shared.reportIncident(req)
                successMessage = "Báo cáo sự cố thành công!"
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
            } catch {
                print("[IncidentVM] loadIncidents error: \(error)")
            }
            isLoading = false
        }
    }

    func updateStatus(incidentId: Int, status: String, needsAssistance: Bool? = nil, hasInjuredMember: Bool? = nil) {
        Task {
            do {
                let req = UpdateIncidentStatusRequest(
                    status: status,
                    needsAssistance: needsAssistance,
                    hasInjuredMember: hasInjuredMember
                )
                try await IncidentService.shared.updateIncidentStatus(incidentId: incidentId, request: req)
                successMessage = "Đã cập nhật trạng thái sự cố"
            } catch {
                errorMessage = "Cập nhật sự cố thất bại: \(error.localizedDescription)"
            }
        }
    }
}
