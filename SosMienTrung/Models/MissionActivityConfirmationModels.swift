import Foundation

struct MissionPickupBufferUsageRequest: Codable {
    let itemId: Int
    let bufferQuantityUsed: Int
    let bufferUsedReason: String?
}

struct MissionConfirmPickupRequest: Codable {
    let bufferUsages: [MissionPickupBufferUsageRequest]?
}

struct MissionConfirmPickupResponse: Codable {
    let activityId: Int
    let missionId: Int
    let message: String
    let updatedSupplies: [MissionSupply]?
}

struct MissionActualDeliveredItemRequest: Codable {
    let itemId: Int
    let actualQuantity: Int
}

struct MissionConfirmDeliveryRequest: Codable {
    let actualDeliveredItems: [MissionActualDeliveredItemRequest]
    let deliveryNote: String?
}

struct MissionConfirmDeliveryResponse: Codable {
    let activityId: Int
    let missionId: Int
    let status: String
    let message: String
    let surplusReturnActivityId: Int?
    let deliveredItems: [MissionDeliveredItemResult]
}

struct MissionDeliveredItemResult: Codable, Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    let actualDeliveredQuantity: Int
    let surplusQuantity: Int

    var id: Int { itemId }
}
