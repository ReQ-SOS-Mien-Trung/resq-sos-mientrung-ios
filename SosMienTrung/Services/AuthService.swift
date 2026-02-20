import Foundation

// MARK: - Auth DTOs
struct RegisterRequest: Codable {
    let phone: String?
    let password: String?
}

struct RegisterResponse: Codable {
    let userId: String
    let phone: String?
    let roleId: Int
    let createdAt: Date
}

/// Error response from server
struct APIErrorResponse: Codable, Sendable {
    let message: String
    
    /// Safe decoding that can be called from any context
    static func decode(from data: Data) -> APIErrorResponse? {
        try? JSONDecoder().decode(APIErrorResponse.self, from: data)
    }
}

struct LoginRequest: Codable {
    let username: String?
    let phone: String?
    let password: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let userId: String
    let username: String?
    let fullName: String?
    let roleId: Int?
}

// MARK: - Auth Service
final class AuthService {
    static let shared = AuthService()

    // NOTE: Use your Mac's LAN IP for Simulator/device testing
    private let baseURL: URL
    private let session: URLSession

    private init(baseURL: URL = URL(string: "http://192.168.2.6:8080")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    enum AuthServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Error)
        case httpStatus(Int, String?)
        case missingData
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL không hợp lệ"
            case .requestFailed(let error):
                return error.localizedDescription
            case .httpStatus(let code, let message):
                return message ?? "Máy chủ trả về lỗi (HTTP \(code))"
            case .missingData:
                return "Không nhận được dữ liệu từ máy chủ"
            case .decodingFailed(let error):
                return "Không thể đọc dữ liệu: \(error.localizedDescription)"
            }
        }
    }

    func register(phone: String?, password: String?, completion: @escaping (Result<RegisterResponse, Error>) -> Void) {
        let payload = RegisterRequest(phone: phone, password: password)
        request(path: "/identity/auth/register", body: payload, completion: completion)
    }

    func login(username: String? = nil, phone: String? = nil, password: String?, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let payload = LoginRequest(username: username, phone: phone, password: password)
        request(path: "/identity/auth/login", body: payload, completion: completion)
    }

    private func request<T: Codable, R: Codable>(
        path: String,
        body: T,
        completion: @escaping (Result<R, Error>) -> Void
    ) {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            DispatchQueue.main.async { completion(.failure(AuthServiceError.invalidURL)) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(AuthServiceError.requestFailed(error))) }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                // Try to parse error message from response
                var errorMessage: String? = nil
                if let data = data, !data.isEmpty {
                    errorMessage = APIErrorResponse.decode(from: data)?.message
                }
                DispatchQueue.main.async { completion(.failure(AuthServiceError.httpStatus(statusCode, errorMessage))) }
                return
            }

            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async { completion(.failure(AuthServiceError.missingData)) }
                return
            }

            do {
                let decoded = try self.makeDecoder().decode(R.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(AuthServiceError.decodingFailed(error))) }
            }
        }
        task.resume()
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let isoNoFraction = ISO8601DateFormatter()
            isoNoFraction.formatOptions = [.withInternetDateTime]

            if let date = isoWithFraction.date(from: value) ?? isoNoFraction.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
        }
        return decoder
    }
}
