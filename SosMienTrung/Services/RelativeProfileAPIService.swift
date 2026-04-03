import Foundation

enum RelativeProfileAPIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(Int, String)
    case invalidProfileId(String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL hồ sơ người thân không hợp lệ"
        case .notAuthenticated:
            return "Chưa đăng nhập"
        case .httpError(let code, let message):
            return message.isEmpty ? "Máy chủ trả về lỗi \(code)" : "Máy chủ trả về lỗi \(code): \(message)"
        case .invalidProfileId(let id):
            return "ID hồ sơ người thân không hợp lệ: \(id)"
        case .decodingError:
            return "Không thể đọc dữ liệu hồ sơ người thân từ máy chủ"
        }
    }
}

private struct RelativeProfilesSyncRequest: Encodable {
    let profiles: [RelativeProfilePayload]
}

private struct RelativeProfilesSyncResponse: Decodable {
    let profiles: [RelativeProfileResponse]
    let createdCount: Int
    let updatedCount: Int
    let deletedCount: Int
    let syncedAt: Date
}

private struct RelativeProfilePayload: Encodable {
    let id: UUID
    let displayName: String
    let phoneNumber: String?
    let personType: String
    let relationGroup: String
    let tags: [String]
    let medicalBaselineNote: String?
    let specialNeedsNote: String?
    let specialDietNote: String?
    let gender: String?
    let medicalProfile: RelativeMedicalProfile?
    let updatedAt: Date

    init(profile: EmergencyRelativeProfile) throws {
        guard let id = UUID(uuidString: profile.id) else {
            throw RelativeProfileAPIError.invalidProfileId(profile.id)
        }

        self.id = id
        self.displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = profile.phoneNumber?.trimmedNilIfBlank
        self.personType = profile.personType.rawValue
        self.relationGroup = profile.relationGroup.rawValue
        self.tags = []
        self.medicalBaselineNote = profile.medicalBaselineNote.nilIfBlank
        self.specialNeedsNote = profile.specialNeedsNote.nilIfBlank
        self.specialDietNote = profile.specialDietNote.nilIfBlank
        self.gender = profile.gender?.rawValue
        self.medicalProfile = profile.medicalProfile.hasContent ? profile.medicalProfile : nil
        self.updatedAt = profile.updatedAt
    }
}

private struct RelativeProfileResponse: Decodable {
    let id: UUID
    let userId: UUID
    let displayName: String
    let phoneNumber: String?
    let personType: String
    let relationGroup: String
    let tags: [String]
    let medicalBaselineNote: String?
    let specialNeedsNote: String?
    let specialDietNote: String?
    let gender: String?
    let medicalProfile: RelativeMedicalProfile?
    let profileUpdatedAt: Date
    let createdAt: Date
    let updatedAt: Date

    func toDomainProfile() -> EmergencyRelativeProfile {
        EmergencyRelativeProfile(
            id: id.uuidString,
            displayName: displayName,
            phoneNumber: phoneNumber,
            personType: Person.PersonType(rawValue: personType) ?? .adult,
            gender: gender.flatMap(ClothingGender.init(rawValue:)),
            relationGroup: RelationGroup(rawValue: relationGroup) ?? .khac,
            medicalProfile: medicalProfile ?? RelativeMedicalProfile(),
            medicalBaselineNote: medicalBaselineNote ?? "",
            specialNeedsNote: specialNeedsNote ?? "",
            specialDietNote: specialDietNote ?? "",
            updatedAt: profileUpdatedAt
        )
    }
}

final class RelativeProfileAPIService {
    static let shared = RelativeProfileAPIService()

    private let baseURL: String
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.baseURL = AppConfig.baseURLString
        self.session = session
    }

    func fetchRelativeProfiles() async throws -> [EmergencyRelativeProfile] {
        let response: [RelativeProfileResponse] = try await request("/identity/user/me/relative-profiles")
        return response.map { $0.toDomainProfile() }
    }

    func createRelativeProfile(_ profile: EmergencyRelativeProfile) async throws -> EmergencyRelativeProfile {
        let body = try Self.encoder().encode(try RelativeProfilePayload(profile: profile))
        let response: RelativeProfileResponse = try await request(
            "/identity/user/me/relative-profiles",
            method: "POST",
            body: body
        )
        return response.toDomainProfile()
    }

    func updateRelativeProfile(_ profile: EmergencyRelativeProfile) async throws -> EmergencyRelativeProfile {
        let payload = try RelativeProfilePayload(profile: profile)
        let body = try Self.encoder().encode(payload)
        let response: RelativeProfileResponse = try await request(
            "/identity/user/me/relative-profiles/\(payload.id.uuidString)",
            method: "PUT",
            body: body
        )
        return response.toDomainProfile()
    }

    func deleteRelativeProfile(id: String) async throws {
        guard let uuid = UUID(uuidString: id) else {
            throw RelativeProfileAPIError.invalidProfileId(id)
        }

        _ = try await requestData(
            "/identity/user/me/relative-profiles/\(uuid.uuidString)",
            method: "DELETE"
        )
    }

    func syncRelativeProfiles(_ profiles: [EmergencyRelativeProfile]) async throws -> [EmergencyRelativeProfile] {
        let payload = try profiles.map(RelativeProfilePayload.init(profile:))
        let body = try Self.encoder().encode(RelativeProfilesSyncRequest(profiles: payload))
        let response: RelativeProfilesSyncResponse = try await request(
            "/identity/user/me/relative-profiles/sync",
            method: "PUT",
            body: body
        )
        return response.profiles.map { $0.toDomainProfile() }
    }

    func clearRelativeProfilesFromServer() async throws {
        _ = try await syncRelativeProfiles([])
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let data = try await requestData(path, method: method, body: body)

        do {
            return try Self.decoder().decode(T.self, from: data)
        } catch {
            throw RelativeProfileAPIError.decodingError(error)
        }
    }

    private func requestData(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let token = AuthSessionStore.shared.session?.accessToken, !token.isEmpty else {
            throw RelativeProfileAPIError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RelativeProfileAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RelativeProfileAPIError.httpError(-1, "Khong nhan duoc phan hoi hop le")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = APIErrorResponse.decode(from: data)?.message
                ?? String(data: data, encoding: .utf8)
                ?? ""
            throw RelativeProfileAPIError.httpError(httpResponse.statusCode, message)
        }

        return data
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, nestedEncoder in
            var container = nestedEncoder.singleValueContainer()
            try container.encode(iso8601WithFractionalSeconds.string(from: date))
        }
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { nestedDecoder in
            let container = try nestedDecoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = iso8601WithFractionalSeconds.date(from: value)
                ?? iso8601.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid relative profile date format: \(value)"
            )
        }
        return decoder
    }
}

private let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedNilIfBlank: String? {
        nilIfBlank
    }
}

private extension Optional where Wrapped == String {
    var trimmedNilIfBlank: String? {
        switch self {
        case .some(let value):
            return value.trimmedNilIfBlank
        case .none:
            return nil
        }
    }
}
