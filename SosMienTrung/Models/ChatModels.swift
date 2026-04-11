import Foundation

// MARK: - Enums

enum ConversationStatus: String, Codable {
    case aiAssist           = "AiAssist"
    case waitingCoordinator = "WaitingCoordinator"
    case coordinatorActive  = "CoordinatorActive"
    case closed             = "Closed"
}

// Tách biệt với MessageType của Bridgefy (Models/Message.swift)
enum CoordinatorMessageType: String, Codable {
    case userMessage   = "UserMessage"
    case aiMessage     = "AiMessage"
    case systemMessage = "SystemMessage"
}

// MARK: - Step 1: GET /operations/conversations/my-conversation

struct ConversationResponse: Codable {
    let conversationId: Int
    let victimId: String?
    let status: ConversationStatus
    let selectedTopic: String?
    let linkedSosRequestId: Int?
    let createdAt: String?
    let aiGreetingMessage: String?
    let topicSuggestions: [TopicSuggestion]
    let participants: [ParticipantDto]
}

struct TopicSuggestion: Codable, Identifiable {
    var id: String { topicKey }
    let topicKey: String
    let label: String
    let description: String?
    let icon: String?
}

struct ParticipantDto: Codable {
    let userId: String?
    let userName: String?
    let role: String?
    let joinedAt: String?
}

// MARK: - GET /operations/conversations/my-conversations

struct VictimConversationSummary: Codable {
    let conversationId: Int
    let status: ConversationStatus
    let selectedTopic: String?
    let linkedSosRequestId: Int?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Step 2: POST /select-topic

struct SelectTopicRequest: Codable {
    let topicKey: String
}

struct SelectTopicResponse: Codable {
    let conversationId: Int
    let status: ConversationStatus
    let topicKey: String
    let aiResponseMessage: String
    let sosRequests: [SosRequestDto]?
}

// MARK: - Step 3: POST /link-sos-request

struct LinkSosRequest: Codable {
    let sosRequestId: Int
}

struct LinkSosResponse: Codable {
    let conversationId: Int
    let linkedSosRequestId: Int
    let status: ConversationStatus
    let aiConfirmationMessage: String
}

// MARK: - SOS Request DTO

struct SosRequestDto: Codable, Identifiable {
    let id: Int
    let sosType: String?
    let msg: String
    let status: String
    let priorityLevel: String?
    let waitTimeMinutes: Int?
    let latitude: Double?
    let longitude: Double?
    let createdAt: String?
}

// MARK: - Step 4: SignalR Chat Message

struct CoordinatorChatMessage: Codable, Identifiable {
    let id: Int
    let conversationId: Int
    let senderId: String?
    let senderName: String?
    let content: String
    let messageType: String
    let createdAt: String
}

struct CoordinatorJoinedPayload: Codable {
    let conversationId: Int
    let coordinatorId: String
    let status: String
    let systemMessage: String
}

// MARK: - Step 5: GET /messages

struct MessagesResponse: Codable {
    let conversationId: Int
    let page: Int
    let pageSize: Int
    let messages: [MessageDto]
}

struct MessageDto: Codable, Identifiable {
    let id: Int
    let senderId: String?
    let senderName: String?
    let content: String?
    let messageType: CoordinatorMessageType
    let createdAt: String?
}

// MARK: - Structured chat payload: SOS quick dispatch

struct SosQuickDispatchCardPayload: Codable, Equatable {
    static let messagePrefix = "[SOS_QUICK_DISPATCH]"
    static let payloadKind = "SosQuickDispatchCard"
    static let payloadVersion = 1

    let kind: String
    let version: Int
    let sosRequestId: Int
    let sosType: String?
    let status: String
    let priorityLevel: String?
    let waitTimeMinutes: Int?
    let summary: String
    let latitude: Double?
    let longitude: Double?
    let createdAt: String?
    let sharedByName: String?
    let sharedAt: String

    init(
        kind: String = SosQuickDispatchCardPayload.payloadKind,
        version: Int = SosQuickDispatchCardPayload.payloadVersion,
        sosRequestId: Int,
        sosType: String?,
        status: String,
        priorityLevel: String?,
        waitTimeMinutes: Int?,
        summary: String,
        latitude: Double?,
        longitude: Double?,
        createdAt: String?,
        sharedByName: String?,
        sharedAt: String
    ) {
        self.kind = kind
        self.version = version
        self.sosRequestId = sosRequestId
        self.sosType = sosType
        self.status = status
        self.priorityLevel = priorityLevel
        self.waitTimeMinutes = waitTimeMinutes
        self.summary = summary
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.sharedByName = sharedByName
        self.sharedAt = sharedAt
    }

    static func from(sos: SosRequestDto, sharedByName: String?) -> SosQuickDispatchCardPayload {
        SosQuickDispatchCardPayload(
            sosRequestId: sos.id,
            sosType: sos.sosType,
            status: sos.status,
            priorityLevel: sos.priorityLevel,
            waitTimeMinutes: sos.waitTimeMinutes,
            summary: sos.msg,
            latitude: sos.latitude,
            longitude: sos.longitude,
            createdAt: sos.createdAt,
            sharedByName: sharedByName,
            sharedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    func encodedMessageContent() -> String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(self),
            let raw = String(data: data, encoding: .utf8)
        else {
            return summary
        }
        return Self.messagePrefix + raw
    }

    static func decode(from messageContent: String) -> SosQuickDispatchCardPayload? {
        guard messageContent.hasPrefix(Self.messagePrefix) else { return nil }
        let raw = String(messageContent.dropFirst(Self.messagePrefix.count))
        guard let data = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(SosQuickDispatchCardPayload.self, from: data) else {
            return nil
        }
        guard payload.kind == Self.payloadKind, payload.version == Self.payloadVersion else {
            return nil
        }
        return payload
    }
}

enum SosDisplayFormatter {
    static func normalizedKey(_ raw: String?) -> String {
        guard let raw else { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.replacingOccurrences(
            of: "[\\s_-]",
            with: "",
            options: .regularExpression
        )
    }

    static func localizedStatus(_ raw: String?) -> String {
        let key = normalizedKey(raw)
        switch key {
        case "pending", "waiting", "queued", "new":
            return "Chờ xử lý"
        case "approved", "accepted":
            return "Đã tiếp nhận"
        case "assigned":
            return "Đã phân công"
        case "inprogress", "ongoing", "processing":
            return "Đang xử lý"
        case "resolved", "closed", "completed", "done":
            return "Đã xử lý"
        case "rejected", "declined":
            return "Từ chối"
        case "cancelled", "canceled", "cancel":
            return "Đã hủy"
        case "escalated", "escalating":
            return "Đã nâng mức"
        default:
            let fallback = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return fallback.isEmpty ? "Không rõ" : fallback
        }
    }

    static func localizedPriority(_ raw: String?) -> String? {
        let key = normalizedKey(raw)
        switch key {
        case "low":
            return "Thấp"
        case "medium", "normal":
            return "Trung bình"
        case "high":
            return "Cao"
        case "critical", "urgent":
            return "Khẩn cấp"
        default:
            let fallback = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return fallback.isEmpty ? nil : fallback
        }
    }

    static func localizedType(_ raw: String?) -> String? {
        let key = normalizedKey(raw)
        switch key {
        case "rescue":
            return "Cứu hộ"
        case "relief":
            return "Cứu trợ"
        case "both":
            return "Cứu hộ + Cứu trợ"
        case "medical":
            return "Y tế"
        default:
            let fallback = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return fallback.isEmpty ? nil : fallback
        }
    }
}
