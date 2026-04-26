import Foundation

enum L10n {
    static func tr(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }

    static func tr(_ key: String, _ fallback: String, _ args: CVarArg...) -> String {
        let format = tr(key, fallback)
        return String(format: format, locale: Locale.current, arguments: args)
    }

    enum Common {
        static let unknown = L10n.tr("common.unknown", "Không xác định")
        static let notClear = L10n.tr("common.not_clear", "Không rõ")
        static let invalidURL = L10n.tr("common.invalid_url", "URL không hợp lệ")
        static let notAuthenticated = L10n.tr("common.not_authenticated", "Bạn chưa đăng nhập")
        static let serverDataDecodeFailed = L10n.tr("common.server_data_decode_failed", "Không đọc được dữ liệu phản hồi từ máy chủ")
        static let noServerData = L10n.tr("common.no_server_data", "Không nhận được dữ liệu từ máy chủ")
        static let draftSaved = L10n.tr("common.draft_saved", "Đã lưu nháp")
        static let submitSucceeded = L10n.tr("common.submit_succeeded", "Đã nộp thành công")
        static let updateSucceeded = L10n.tr("common.update_succeeded", "Đã cập nhật thành công")
        static let checkInSucceeded = L10n.tr("common.check_in_succeeded", "Xác nhận có mặt thành công")
        static let checkOutSucceeded = L10n.tr("common.check_out_succeeded", "Xác nhận rời đi thành công")
        static let invalidNotificationURL = L10n.tr("common.invalid_notification_url", "URL thông báo không hợp lệ")
        static let invalidNotificationHubURL = L10n.tr("common.invalid_notification_hub_url", "URL NotificationHub không hợp lệ")
        static let invalidChatHubURL = L10n.tr("common.invalid_chat_hub_url", "URL hub không hợp lệ")

        static func serverError(_ code: String) -> String {
            L10n.tr("common.server_error", "Máy chủ trả về lỗi %@", code)
        }

        static func serverErrorWithMessage(_ code: String, _ message: String) -> String {
            L10n.tr("common.server_error_with_message", "Máy chủ trả về lỗi %@: %@", code, message)
        }

        static func cannotDecodeData(_ detail: String) -> String {
            L10n.tr("common.cannot_decode_data", "Không thể đọc dữ liệu: %@", detail)
        }

        static func timeoutCheckConnection() -> String {
            L10n.tr("common.timeout_check_connection", "Hết thời gian chờ – kiểm tra lại IP máy chủ và kết nối mạng")
        }
    }

    enum Domain {
        static let missionInProgress = L10n.tr("domain.mission.in_progress", "Đang thực hiện")
        static let missionPlanned = L10n.tr("domain.mission.planned", "Đã lên kế hoạch")
        static let missionCompleted = L10n.tr("domain.mission.completed", "Đã hoàn thành")
        static let missionIncomplete = L10n.tr("domain.mission.incomplete", "Chưa hoàn thành")
        static let missionCancelled = L10n.tr("domain.mission.cancelled", "Đã hủy")

        static let teamReady = L10n.tr("domain.team.ready", "Sẵn sàng")
        static let teamGathering = L10n.tr("domain.team.gathering", "Tập kết")
        static let teamAssigned = L10n.tr("domain.team.assigned", "Đã phân công")
        static let teamOnMission = L10n.tr("domain.team.on_mission", "Đang làm nhiệm vụ")
        static let teamStuck = L10n.tr("domain.team.stuck", "Gặp sự cố")
        static let teamAwaitingAcceptance = L10n.tr("domain.team.awaiting_acceptance", "Chờ xác nhận")
        static let teamUnavailable = L10n.tr("domain.team.unavailable", "Không sẵn sàng")
        static let teamDisbanded = L10n.tr("domain.team.disbanded", "Đã giải tán")

        static let activityPendingWarehouseConfirmation = L10n.tr("domain.activity.pending_warehouse_confirmation", "Chờ kho xác nhận")
        static let activityFailed = L10n.tr("domain.activity.failed", "Thất bại")
        static let activityCompleted = L10n.tr("domain.activity.completed", "Hoàn thành")

        static let assemblyScheduled = L10n.tr("domain.assembly.scheduled", "Đã lên lịch")
        static let assemblyGathering = L10n.tr("domain.assembly.gathering", "Đang tập trung")
        static let assemblyCompleted = L10n.tr("domain.assembly.completed", "Đã hoàn tất")

        static let incidentReported = L10n.tr("domain.incident.reported", "Đã báo cáo")
        static let incidentInProgress = L10n.tr("domain.incident.in_progress", "Đang xử lý")
        static let incidentResolved = L10n.tr("domain.incident.resolved", "Đã xử lý")

        static let sosPending = L10n.tr("domain.sos.pending", "Chờ xử lý")
        static let sosAccepted = L10n.tr("domain.sos.accepted", "Đã tiếp nhận")
        static let sosAssigned = L10n.tr("domain.sos.assigned", "Đã phân công")
        static let sosInProgress = L10n.tr("domain.sos.in_progress", "Đang xử lý")
        static let sosResolved = L10n.tr("domain.sos.resolved", "Đã xử lý")
        static let sosRejected = L10n.tr("domain.sos.rejected", "Từ chối")
        static let sosCancelled = L10n.tr("domain.sos.cancelled", "Đã hủy")
        static let sosEscalated = L10n.tr("domain.sos.escalated", "Đã nâng mức")

        static let priorityLow = L10n.tr("domain.priority.low", "Thấp")
        static let priorityMedium = L10n.tr("domain.priority.medium", "Trung bình")
        static let priorityHigh = L10n.tr("domain.priority.high", "Cao")
        static let priorityCritical = L10n.tr("domain.priority.critical", "Khẩn cấp")

        static let sosTypeRescue = L10n.tr("domain.sos_type.rescue", "Cứu hộ")
        static let sosTypeRelief = L10n.tr("domain.sos_type.relief", "Cứu trợ")
        static let sosTypeRescueRelief = L10n.tr("domain.sos_type.rescue_relief", "Cứu hộ + Cứu trợ")
        static let sosTypeMedical = L10n.tr("domain.sos_type.medical", "Y tế")

        static let activityTypeCollectSupplies = L10n.tr("domain.activity_type.collect_supplies", "Tiếp nhận vật phẩm")
        static let activityTypeDeliverSupplies = L10n.tr("domain.activity_type.deliver_supplies", "Phân phát vật phẩm")
        static let activityTypeReturnSupplies = L10n.tr("domain.activity_type.return_supplies", "Hoàn trả vật phẩm")
        static let activityTypeReturnAssemblyPoint = L10n.tr("domain.activity_type.return_assembly_point", "Quay về điểm tập kết")
        static let activityTypeRescue = L10n.tr("domain.activity_type.rescue", "Cứu hộ")
        static let activityTypeFirstAid = L10n.tr("domain.activity_type.first_aid", "Sơ cứu y tế")
        static let activityTypeMedicalSupport = L10n.tr("domain.activity_type.medical_support", "Hỗ trợ y tế")
        static let activityTypeEvacuate = L10n.tr("domain.activity_type.evacuate", "Di tản")
        static let activityTypeSearchAndRescue = L10n.tr("domain.activity_type.search_and_rescue", "Tìm kiếm cứu nạn")
        static let activityTypeLogistics = L10n.tr("domain.activity_type.logistics", "Hậu cần")
        static let activityTypeTransport = L10n.tr("domain.activity_type.transport", "Vận chuyển")
        static let activityTypeAssessment = L10n.tr("domain.activity_type.assessment", "Đánh giá hiện trường")

        static let userRoleCivilian = L10n.tr("domain.user_role.civilian", "Người dân")
        static let userRoleRescuer = L10n.tr("domain.user_role.rescuer", "Cứu hộ viên")
        static let userRoleCoordinator = L10n.tr("domain.user_role.coordinator", "Điều phối viên")
        static let userRoleAdmin = L10n.tr("domain.user_role.admin", "Quản trị viên")
    }

    enum VictimChat {
        static let notLoggedIn = L10n.tr("victim_chat.not_logged_in", "Chưa đăng nhập, vui lòng đăng nhập lại")

        static func cannotOpenChat(_ detail: String) -> String {
            L10n.tr("victim_chat.cannot_open_chat", "Không thể mở cuộc trò chuyện: %@", detail)
        }

        static func uploadImageFailed(_ detail: String) -> String {
            L10n.tr("victim_chat.upload_image_failed", "Tải ảnh lên thất bại: %@", detail)
        }

        static func cannotLoadHistory(_ detail: String) -> String {
            L10n.tr("victim_chat.cannot_load_history", "Không thể tải lịch sử: %@", detail)
        }
    }

    enum MissionTeamReport {
        static let waitingForSubmitStatus = L10n.tr("mission_team_report.waiting_submit_status", "Đội đã được chuyển sang trạng thái chờ nộp báo cáo.")
        static let draftSaved = L10n.tr("mission_team_report.draft_saved", "Đã lưu nháp báo cáo đội.")
        static let finalSubmitted = L10n.tr("mission_team_report.final_submitted", "Đã nộp báo cáo cuối cùng.")
        static let nonLeaderCannotSaveEvaluations = L10n.tr("mission_team_report.non_leader_cannot_save_evaluations", "Chỉ đội trưởng mới được lưu đánh giá thành viên. Vui lòng nhờ đội trưởng lưu báo cáo để tránh mất dữ liệu.")
        static let nonLeaderDraftRestriction = L10n.tr("mission_team_report.non_leader_draft_restriction", "Chỉ đội trưởng mới được lưu đánh giá thành viên. Nếu bạn lưu nháp lúc này, hệ thống sẽ xóa phần đánh giá đã có.")

        static func cannotLoad(_ detail: String) -> String {
            L10n.tr("mission_team_report.cannot_load", "Không thể tải báo cáo đội: %@", detail)
        }

        static func cannotCompleteFieldWork(_ detail: String) -> String {
            L10n.tr("mission_team_report.cannot_complete_field_work", "Không thể hoàn tất nhiệm vụ: %@", detail)
        }

        static func cannotSaveDraft(_ detail: String) -> String {
            L10n.tr("mission_team_report.cannot_save_draft", "Không thể lưu nháp báo cáo: %@", detail)
        }

        static func cannotSubmit(_ detail: String) -> String {
            L10n.tr("mission_team_report.cannot_submit", "Không thể nộp báo cáo: %@", detail)
        }

        static func invalidJSON(_ field: String) -> String {
            L10n.tr("mission_team_report.invalid_json", "%@ không phải JSON hợp lệ.", field)
        }

        static func partialMemberEvaluation(_ memberName: String) -> String {
            L10n.tr("mission_team_report.partial_member_evaluation", "Hãy chấm đủ 5 tiêu chí cho %@ hoặc xóa toàn bộ điểm đang nhập dở.", memberName)
        }

        static func missingMemberEvaluation(_ memberName: String) -> String {
            L10n.tr("mission_team_report.missing_member_evaluation", "Cần đánh giá đầy đủ cho %@ trước khi nộp báo cáo.", memberName)
        }

        static func missingDeliveryShortfallReason(_ activityName: String) -> String {
            L10n.tr("mission_team_report.missing_delivery_shortfall_reason", "Cần nhập lý do giao thiếu cho %@ trước khi nộp báo cáo.", activityName)
        }
    }

    enum RescuerMission {
        static let missingAssemblyPointId = L10n.tr("rescuer_mission.missing_assembly_point_id", "Không tìm thấy assemblyPointId để xác nhận có mặt. Vui lòng đồng bộ lại dữ liệu đội cứu hộ.")
        static let activityWaitingServerSync = L10n.tr("rescuer_mission.activity_waiting_server_sync", "Hoạt động này đang chờ đồng bộ máy chủ.")
        static let missingLocalActivity = L10n.tr("rescuer_mission.missing_local_activity", "Không tìm thấy hoạt động để lưu cục bộ.")
        static let cannotSaveOfflineAction = L10n.tr("rescuer_mission.cannot_save_offline_action", "Không thể lưu thao tác ngoại tuyến cho hoạt động này.")
        static let offlineSavedWaitingSync = L10n.tr("rescuer_mission.offline_saved_waiting_sync", "Đã lưu cục bộ. Hoạt động đang chờ đồng bộ máy chủ.")
        static let proofImageRequiresConnection = L10n.tr("rescuer_mission.proof_image_requires_connection", "Không có mạng để tải ảnh minh chứng. Vui lòng thử lại hoặc hoàn thành bước mà không đính kèm ảnh.")
        static let activityStatusUpdated = L10n.tr("rescuer_mission.activity_status_updated", "Đã cập nhật trạng thái bước thực hiện")
        static let supplyPickupConfirmed = L10n.tr("rescuer_mission.supply_pickup_confirmed", "Đã xác nhận tiếp nhận vật phẩm")
        static let missionStatusUpdated = L10n.tr("rescuer_mission.mission_status_updated", "Đã cập nhật trạng thái nhiệm vụ")
        static let safetyCheckInSucceeded = L10n.tr("rescuer_mission.safety_check_in_succeeded", "Đã báo đội đang an toàn")
        static let safetyCheckInRequiresConnection = L10n.tr("rescuer_mission.safety_check_in_requires_connection", "Cần có mạng để báo an toàn cho đội.")
        static let teamAvailable = L10n.tr("rescuer_mission.team_available", "Đội đã sẵn sàng nhận nhiệm vụ")
        static let teamUnavailable = L10n.tr("rescuer_mission.team_unavailable", "Đội đã chuyển sang trạng thái không sẵn sàng")
        static let leaveTeamSucceeded = L10n.tr("rescuer_mission.leave_team_succeeded", "Bạn đã rời đội cứu hộ hiện tại")
        static let cannotLeaveTeamDuringAssignedOrOnMission = L10n.tr("rescuer_mission.cannot_leave_team_during_assigned_or_on_mission", "Không thể rời đội khi đội đang được phân công hoặc đang làm nhiệm vụ")

        static func currentLocationUnavailable() -> String {
            L10n.tr("rescuer_mission.current_location_unavailable", "Không thể lấy vị trí hiện tại. Vui lòng kiểm tra quyền truy cập vị trí hoặc chờ GPS cập nhật rồi thử lại.")
        }

        static func cannotLoadTeamInfo(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_load_team_info", "Không thể tải thông tin đội: %@", detail)
        }

        static func checkInFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.check_in_failed", "Xác nhận có mặt thất bại: %@", detail)
        }

        static func checkOutFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.check_out_failed", "Xác nhận rời đi thất bại: %@", detail)
        }

        static func cannotUpdateTeamStatus(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_update_team_status", "Không thể cập nhật trạng thái đội: %@", detail)
        }

        static func cannotLeaveTeam(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_leave_team", "Không thể rời đội: %@", detail)
        }

        static func cannotLoadMissions(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_load_missions", "Không thể tải danh sách nhiệm vụ: %@", detail)
        }

        static func cannotLoadActivities(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_load_activities", "Không thể tải các bước thực hiện: %@", detail)
        }

        static func activityStatusUpdateFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.activity_status_update_failed", "Cập nhật trạng thái bước thực hiện thất bại: %@", detail)
        }

        static func supplyPickupFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.supply_pickup_failed", "Xác nhận tiếp nhận vật phẩm thất bại: %@", detail)
        }

        static func supplyDeliveryFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.supply_delivery_failed", "Xác nhận phân phát vật phẩm thất bại: %@", detail)
        }

        static func missionStatusUpdateFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.mission_status_update_failed", "Không thể cập nhật trạng thái nhiệm vụ: %@", detail)
        }

        static func safetyCheckInFailed(_ detail: String) -> String {
            L10n.tr("rescuer_mission.safety_check_in_failed", "Báo an toàn thất bại: %@", detail)
        }

        static func cannotLoadAssemblyEvents(_ detail: String) -> String {
            L10n.tr("rescuer_mission.cannot_load_assembly_events", "Không thể tải danh sách sự kiện tập kết: %@", detail)
        }
    }

    enum Incident {
        static let reportCreatedWithTeamRequest = L10n.tr("incident.report_created_with_team_request", "Đã báo sự cố nhiệm vụ và gửi kèm yêu cầu giải cứu đội")
        static let reportCreatedWithHandover = L10n.tr("incident.report_created_with_handover", "Đã báo sự cố nhiệm vụ và gửi thông tin bàn giao")
        static let reportCreatedForWholeTeam = L10n.tr("incident.report_created_for_whole_team", "Đã báo sự cố nhiệm vụ cho toàn đội")
        static let activityReportCreated = L10n.tr("incident.activity_report_created", "Đã báo sự cố hoạt động")
        static let activityReportCreatedWithSupport = L10n.tr("incident.activity_report_created_with_support", "Đã báo sự cố hoạt động và gửi kèm yêu cầu hỗ trợ")
        static let incidentStatusUpdated = L10n.tr("incident.status_updated", "Đã cập nhật trạng thái sự cố")

        static func reportCreatedWithAssistance(_ assistanceId: String) -> String {
            L10n.tr("incident.report_created_with_assistance", "Đã báo sự cố nhiệm vụ và tạo yêu cầu giải cứu #%@", assistanceId)
        }

        static func reportFailed(_ detail: String) -> String {
            L10n.tr("incident.report_failed", "Báo cáo thất bại: %@", detail)
        }

        static func incidentStatusUpdateFailed(_ detail: String) -> String {
            L10n.tr("incident.status_update_failed", "Cập nhật sự cố thất bại: %@", detail)
        }
    }

    enum PhoneAuth {
        static let sessionExpiredResendOTP = L10n.tr("phone_auth.session_expired_resend_otp", "Phiên xác thực hết hạn, vui lòng gửi lại OTP")
        static let rescuerAccountInvalidRole = L10n.tr("phone_auth.rescuer_account_invalid_role", "Tài khoản này không thuộc nhóm người cứu hộ.")
        static let apnsTokenMissing = L10n.tr("phone_auth.apns_token_missing", "Thiết bị chưa nhận APNs token. Hãy chờ vài giây sau khi mở ứng dụng rồi gửi lại OTP trên thiết bị thật.")
        static let apiKeyHTTPReferrerBlocked = L10n.tr("phone_auth.api_key_http_referrer_blocked", "Firebase API key hiện đang bị chặn theo HTTP referrer nên iOS không gọi được Phone Auth. Vào Google Cloud Console > APIs & Services > Credentials > chọn API key của Firebase và bỏ Application restriction kiểu HTTP referrers (hoặc tạo key mới cho iOS/Firebase), sau đó tải lại GoogleService-Info.plist và thay vào ứng dụng.")
        static let permissionDenied = L10n.tr("phone_auth.permission_denied", "Firebase từ chối quyền truy cập (403). Hãy kiểm tra API key trong GoogleService-Info.plist và cấu hình restriction của key trên Google Cloud/Firebase Console.")
        static let deviceVerificationError39 = L10n.tr("phone_auth.device_verification_error_39", "Lỗi xác thực thiết bị (Error 39). Vui lòng kiểm tra:\n• Chạy trên thiết bị thật (không phải Simulator)\n• APNs đã được cấu hình đúng\n• Thử lại sau vài phút")
        static let smsServiceUnavailable = L10n.tr("phone_auth.sms_service_unavailable", "Dịch vụ SMS tạm thời không khả dụng (503), vui lòng thử lại sau")
        static let invalidVerificationCode = L10n.tr("phone_auth.invalid_verification_code", "Mã OTP không đúng")
        static let tooManyRequests = L10n.tr("phone_auth.too_many_requests", "Bạn đã gửi OTP quá nhiều lần, vui lòng thử lại sau")
        static let invalidPhoneNumber = L10n.tr("phone_auth.invalid_phone_number", "Số điện thoại không hợp lệ")
        static let missingPhoneNumber = L10n.tr("phone_auth.missing_phone_number", "Vui lòng nhập số điện thoại")
        static let quotaExceeded = L10n.tr("phone_auth.quota_exceeded", "Đã vượt quá giới hạn gửi OTP, vui lòng thử lại sau")
        static let webContextCancelled = L10n.tr("phone_auth.web_context_cancelled", "Xác minh bị huỷ, vui lòng thử lại")

        static func genericError(_ detail: String) -> String {
            L10n.tr("phone_auth.generic_error", "Lỗi xác thực: %@", detail)
        }
    }

    enum NotificationHub {
        static func cannotDecodeReceiveNotification(_ detail: String) -> String {
            L10n.tr("notification_hub.cannot_decode_receive_notification", "Không thể decode ReceiveNotification: %@", detail)
        }
    }

    enum NotificationAPI {
        static let notAuthenticated = L10n.tr("notification_api.not_authenticated", "Chưa đăng nhập")
        static let invalidResponse = L10n.tr("notification_api.invalid_response", "Không nhận được phản hồi hợp lệ")
        static let decodeFailed = L10n.tr("notification_api.decode_failed", "Không thể đọc dữ liệu thông báo từ máy chủ")
    }

    enum ConversationAPI {
        static let decodingError = L10n.tr("conversation_api.decoding_error", "Không đọc được dữ liệu từ server")

        static func httpError(_ code: String, _ message: String) -> String {
            L10n.tr("conversation_api.http_error", "Lỗi server %@: %@", code, message)
        }
    }

    enum RelativeProfile {
        static let invalidURL = L10n.tr("relative_profile.invalid_url", "URL hồ sơ người thân không hợp lệ")
        static let decodingError = L10n.tr("relative_profile.decoding_error", "Không thể đọc dữ liệu hồ sơ người thân từ máy chủ")

        static func invalidProfileId(_ id: String) -> String {
            L10n.tr("relative_profile.invalid_profile_id", "ID hồ sơ người thân không hợp lệ: %@", id)
        }
    }

    enum Geocoding {
        static let invalidResponse = L10n.tr("geocoding.invalid_response", "Apple Maps không trả về dữ liệu vị trí hợp lệ.")
        static let noResults = L10n.tr("geocoding.no_results", "Không tìm thấy địa chỉ phù hợp trên Apple Maps.")
        static let noAddress = L10n.tr("geocoding.no_address", "Apple Maps chưa đọc được địa chỉ cho vị trí này.")
    }

    enum SOSRuleConfig {
        static let missingAccessToken = L10n.tr("sos_rule_config_service.missing_access_token", "Chưa có access token để tải SOS rule config.")
        static let invalidURL = L10n.tr("sos_rule_config_service.invalid_url", "URL SOS rule config không hợp lệ.")
        static let divideByZero = L10n.tr("sos_rule_config.divide_by_zero", "Biểu thức chia cho 0.")

        static func invalidResponse(_ code: String) -> String {
            L10n.tr("sos_rule_config_service.invalid_response", "Tải SOS rule config thất bại (HTTP %@).", code)
        }

        static func decodingFailed(_ detail: String) -> String {
            L10n.tr("sos_rule_config_service.decoding_failed", "Không đọc được SOS rule config: %@", detail)
        }

        static func missingVariable(_ variable: String) -> String {
            L10n.tr("sos_rule_config.missing_variable", "Thiếu biến %@ trong context tính điểm.", variable)
        }
    }

    enum MissionService {
        static let invalidResponse = L10n.tr("mission_service.invalid_response", "Phản hồi máy chủ không hợp lệ")

        static func httpStatus(_ code: String) -> String {
            L10n.tr("mission_service.http_status", "Máy chủ trả về lỗi (HTTP %@)", code)
        }
    }

    enum Media {
        static let invalidImageData = L10n.tr("media.invalid_image_data", "Không thể xử lý dữ liệu ảnh")
        static let invalidUploadResponse = L10n.tr("media.invalid_upload_response", "Phản hồi tải ảnh lên không hợp lệ")
        static let missingUploadedURL = L10n.tr("media.missing_uploaded_url", "Cloudinary không trả về URL ảnh")

        static func uploadFailed(_ statusCode: String) -> String {
            L10n.tr("media.upload_failed", "Tải ảnh lên lỗi (HTTP %@)", statusCode)
        }
    }

    enum VictimChatService {
        static func cannotJoinRoom(_ detail: String) -> String {
            L10n.tr("victim_chat_service.cannot_join_room", "Không thể tham gia phòng trò chuyện: %@", detail)
        }

        static func sendFailed(_ detail: String) -> String {
            L10n.tr("victim_chat_service.send_failed", "Gửi thất bại: %@", detail)
        }
    }

    enum Route {
        static let deviceGPS = L10n.tr("route.device_gps", "GPS thiết bị")
        static let teamLocation = L10n.tr("route.team_location", "Vị trí đội")
        static let teamCoordinate = L10n.tr("route.team_coordinate", "Tọa độ đội")
        static let unknownOrigin = L10n.tr("route.unknown_origin", "Chưa xác định được điểm xuất phát")
        static let dash = L10n.tr("route.dash", "-")
        static let activityLocationUnavailable = L10n.tr("route.activity_location_unavailable", "Chưa lấy được GPS của thiết bị và cũng không có vị trí đội để tính lộ trình. Nếu đang dùng trình giả lập iPhone, hãy chọn Features > Location để cấp vị trí mô phỏng.")
        static let aggregateLocationUnavailable = L10n.tr("route.aggregate_location_unavailable", "Chưa lấy được GPS thiết bị và cũng không có tọa độ đội để bắt đầu chỉ đường.")

        static func destinationStep(_ step: String) -> String {
            L10n.tr("route.destination_step", "Điểm đến bước %@", step)
        }

        static func hoursMinutes(_ hours: String, _ minutes: String) -> String {
            L10n.tr("route.hours_minutes", "%@ giờ %@ phút", hours, minutes)
        }

        static func minutesOnly(_ minutes: String) -> String {
            L10n.tr("route.minutes_only", "%@ phút", minutes)
        }

        static let activityMissingRouteData = L10n.tr("route.activity.missing_route_data", "Hệ thống chưa trả về dữ liệu lộ trình cho bước này.")
        static let aggregateMissingMissionTeamId = L10n.tr("route.aggregate.missing_mission_team_id", "Không có mã đội của nhiệm vụ nên chưa thể lấy lộ trình của đội.")
        static let aggregateMissingRouteData = L10n.tr("route.aggregate.missing_route_data", "API lộ trình của đội chưa trả về dữ liệu lộ trình.")

        static func activityLoadFailed(_ detail: String) -> String {
            L10n.tr("route.activity.load_failed", "Không thể tải lộ trình: %@", detail)
        }

        static func aggregateInvalidStatus(_ status: String) -> String {
            L10n.tr("route.aggregate.invalid_status", "API lộ trình của đội trả về trạng thái không hợp lệ: %@", status)
        }

        static func aggregateLoadFailed(_ detail: String) -> String {
            L10n.tr("route.aggregate.load_failed", "Không thể tải lộ trình tổng hợp: %@", detail)
        }

        static func aggregateActivityFallbackTitle(_ id: String) -> String {
            L10n.tr("route.aggregate.activity_fallback_title", "Hoạt động #%@", id)
        }
    }

    enum RescueTeam {
        static let notAssignedYet = L10n.tr("rescue_team.not_assigned_yet", "Bạn chưa được phân vào đội cứu hộ.")

        static func noValidAssemblyEvent(_ assemblyPointId: String) -> String {
            L10n.tr("rescue_team.no_valid_assembly_event", "Không tìm thấy sự kiện tập trung hợp lệ cho điểm tập kết %@", assemblyPointId)
        }
    }

    enum Mission {
        static let defaultTitle = L10n.tr("mission.default_title", "Nhiệm vụ")
        static let executionStepTitle = L10n.tr("mission.execution_step_title", "Bước thực hiện")
        static let sharedExecutionPoint = L10n.tr("mission.shared_execution_point", "Cùng điểm thực hiện")
        static let executionPoint = L10n.tr("mission.execution_point", "Điểm thực hiện")
        static let missionTypeRescue = L10n.tr("mission.type.rescue", "Cứu hộ")
        static let missionTypeEvacuation = L10n.tr("mission.type.evacuation", "Di tản")
        static let missionTypeMedical = L10n.tr("mission.type.medical", "Y tế")
        static let missionTypeRelief = L10n.tr("mission.type.relief", "Cứu trợ")
        static let missionTypeMixed = L10n.tr("mission.type.mixed", "Tổng hợp")
        static let missionTypeRescuerDispatch = L10n.tr("mission.type.rescuer_dispatch", "Điều động người cứu hộ")

        static func executionStepNumbered(_ step: String) -> String {
            L10n.tr("mission.execution_step_numbered", "Bước thực hiện #%@", step)
        }

        static func sosBadge(_ id: String) -> String {
            L10n.tr("mission.sos_badge", "SOS #%@", id)
        }

        static func sharedStepsAtPoint(_ count: String) -> String {
            L10n.tr("mission.shared_steps_at_point", "%@ bước cùng điểm trong nhiệm vụ", count)
        }

        static func coordinateReadFromDescription(_ label: String) -> String {
            L10n.tr("mission.coordinate_read_from_description", "Đọc từ mô tả: %@", label)
        }

        static func coordinateLabel(_ label: String) -> String {
            L10n.tr("mission.coordinate_label", "Tọa độ: %@", label)
        }

        static func clusterSos(_ id: String) -> String {
            L10n.tr("mission.cluster_sos", "Cụm yêu cầu SOS #%@", id)
        }

        static func severity(_ level: String) -> String {
            L10n.tr("mission.severity", "Mức độ %@", level)
        }

        static func numberedLabel(_ base: String, _ suffix: String) -> String {
            L10n.tr("mission.numbered_label", "%@ #%@", base, suffix)
        }
    }

    enum Handover {
        static let noIdentityToTransfer = L10n.tr("handover.no_identity_to_transfer", "Không có tài khoản để chuyển")
        static let identityAlreadyTransferred = L10n.tr("handover.identity_already_transferred", "Tài khoản đã được chuyển sang thiết bị khác")
        static let tokenExpired = L10n.tr("handover.token_expired", "Mã xác nhận đã hết hạn")
        static let tokenInvalid = L10n.tr("handover.token_invalid", "Mã xác nhận không hợp lệ")
        static let signatureInvalid = L10n.tr("handover.signature_invalid", "Chữ ký số không hợp lệ")
        static let replayAttack = L10n.tr("handover.replay_attack", "Phát hiện tấn công replay - mã đã được sử dụng")
        static let peerNotConnected = L10n.tr("handover.peer_not_connected", "Chưa kết nối với thiết bị")
        static let transferInProgress = L10n.tr("handover.transfer_in_progress", "Đang trong quá trình chuyển tài khoản")
        static let userRejected = L10n.tr("handover.user_rejected", "Yêu cầu đã bị từ chối")
        static let invalidQRCode = L10n.tr("handover.invalid_qr_code", "Mã QR không hợp lệ")
        static let concurrentTakeoverAttempt = L10n.tr("handover.concurrent_takeover_attempt", "Phát hiện yêu cầu chuyển tài khoản đồng thời")
        static let oldDeviceOffline = L10n.tr("handover.old_device_offline", "Thiết bị cũ không còn kết nối")

        static func networkError(_ message: String) -> String {
            L10n.tr("handover.network_error", "Lỗi kết nối: %@", message)
        }
    }

    enum Auth {
        static let missingIOSClientID = L10n.tr("auth.google.missing_ios_client_id", "Thiếu iOS OAuth client ID. Hãy thêm GIDClientID hoặc CLIENT_ID từ GoogleService-Info.plist.")
        static let missingServerClientID = L10n.tr("auth.google.missing_server_client_id", "Thiếu GIDServerClientID để BE xác minh Google ID token.")
        static let missingPresentingViewController = L10n.tr("auth.google.missing_presenting_view_controller", "Không tìm thấy màn hình để mở Google Sign-In.")
        static let missingIDToken = L10n.tr("auth.google.missing_id_token", "Google không trả về ID token hợp lệ.")
        static let missingAccessToken = L10n.tr("auth.google.missing_access_token", "Google không trả về access token hợp lệ.")
        static let missingFirebaseIDToken = L10n.tr("auth.google.missing_firebase_id_token", "Firebase không trả về ID token hợp lệ sau khi đăng nhập Google.")
        static let identityKeyGenerationFailed = L10n.tr("auth.identity.key_generation_failed", "Không thể tạo cặp khóa mã hóa")
        static let identityKeyNotFound = L10n.tr("auth.identity.key_not_found", "Không tìm thấy khóa định danh")
        static let identityKeyStorageFailed = L10n.tr("auth.identity.key_storage_failed", "Không thể lưu khóa an toàn")
        static let identitySignatureFailed = L10n.tr("auth.identity.signature_failed", "Không thể ký dữ liệu")
        static let identityVerificationFailed = L10n.tr("auth.identity.verification_failed", "Xác minh chữ ký thất bại")
        static let secureEnclaveUnavailable = L10n.tr("auth.identity.secure_enclave_unavailable", "Secure Enclave không khả dụng trên thiết bị này")
        static let invalidKeyData = L10n.tr("auth.identity.invalid_key_data", "Dữ liệu khóa không hợp lệ")
        static let keyAlreadyRevoked = L10n.tr("auth.identity.key_already_revoked", "Khóa định danh đã bị thu hồi")

        static func missingURLScheme(_ scheme: String) -> String {
            L10n.tr("auth.google.missing_url_scheme", "Thiếu URL scheme iOS cho Google Sign-In: %@", scheme)
        }

        static func keychainError(_ status: String) -> String {
            L10n.tr("auth.identity.keychain_error", "Lỗi Keychain: %@", status)
        }

        static func httpStatus(_ code: String) -> String {
            L10n.tr("auth.http_status", "Máy chủ trả về lỗi (HTTP %@)", code)
        }
    }
}
