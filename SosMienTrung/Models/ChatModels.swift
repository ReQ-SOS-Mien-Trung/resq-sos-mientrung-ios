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
