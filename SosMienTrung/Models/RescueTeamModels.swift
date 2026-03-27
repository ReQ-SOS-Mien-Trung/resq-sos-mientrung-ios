import Foundation

struct RescueTeamMember: Codable, Identifiable {
    let userId: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let avatarUrl: String?
    let rescuerType: String?
    let status: String?
    let isLeader: Bool
    let roleInTeam: String?
    let checkedIn: Bool
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId
        case firstName
        case lastName
        case phone
        case avatarUrl
        case rescuerType
        case status
        case isLeader
        case roleInTeam
        case checkedIn
        case joinedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        rescuerType = try container.decodeIfPresent(String.self, forKey: .rescuerType)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        isLeader = try container.decode(Bool.self, forKey: .isLeader)
        roleInTeam = try container.decodeIfPresent(String.self, forKey: .roleInTeam)
        checkedIn = try container.decodeIfPresent(Bool.self, forKey: .checkedIn) ?? false
        joinedAt = try container.decodeIfPresent(String.self, forKey: .joinedAt)
    }

    var id: String { userId }

    var fullName: String {
        let components = [lastName, firstName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return components.isEmpty ? "Thành viên" : components.joined(separator: " ")
    }

    var role: String? {
        roleInTeam ?? rescuerType
    }
}

struct RescueTeam: Codable, Identifiable {
    let id: Int
    let eventId: Int?
    let code: String
    let name: String
    let teamType: String
    let status: String?
    let assemblyPointId: Int?
    let assemblyPointName: String?
    let managedBy: String
    let maxMembers: Int
    let assemblyDate: String?
    let createdAt: String?
    let members: [RescueTeamMember]?

    var leader: RescueTeamMember? {
        members?.first(where: \.isLeader)
    }
}

struct CheckInResponse: Codable {
    let message: String?
}

struct AssemblyPointEvent: Decodable, Identifiable {
    let eventId: Int
    let assemblyPointId: Int
    let assemblyPointName: String?
    let assemblyDate: String?
    let eventStatus: String?
    let isCheckedIn: Bool
    let checkInTime: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case eventId
        case assemblyPointId
        case assemblyPointName
        case assemblyDate
        case eventStatus
        case status
        case isCheckedIn
        case checkInTime
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(Int.self, forKey: .eventId)
        assemblyPointId = try container.decode(Int.self, forKey: .assemblyPointId)
        assemblyPointName = try container.decodeIfPresent(String.self, forKey: .assemblyPointName)
        assemblyDate = try container.decodeIfPresent(String.self, forKey: .assemblyDate)
        eventStatus = try container.decodeIfPresent(String.self, forKey: .eventStatus)
            ?? container.decodeIfPresent(String.self, forKey: .status)
        isCheckedIn = try container.decodeIfPresent(Bool.self, forKey: .isCheckedIn) ?? false
        checkInTime = try container.decodeIfPresent(String.self, forKey: .checkInTime)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var id: Int { eventId }
}

struct AssemblyPointEventsPage: Decodable {
    let items: [AssemblyPointEvent]
    let pageNumber: Int
    let pageSize: Int
    let totalCount: Int
    let totalPages: Int
    let hasPreviousPage: Bool
    let hasNextPage: Bool
}
