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
