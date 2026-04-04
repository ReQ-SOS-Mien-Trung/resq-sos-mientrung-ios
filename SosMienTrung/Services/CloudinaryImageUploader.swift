import Foundation
import UIKit

private struct CloudinaryUploadResponse: Decodable {
    let secure_url: String
}

enum CloudinaryImageUploadError: LocalizedError {
    case invalidImageData
    case invalidResponse
    case uploadFailed(statusCode: Int, message: String?)
    case missingURL

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Không thể xử lý dữ liệu ảnh"
        case .invalidResponse:
            return "Phản hồi upload không hợp lệ"
        case .uploadFailed(let statusCode, let message):
            return message ?? "Upload ảnh lỗi (HTTP \(statusCode))"
        case .missingURL:
            return "Cloudinary không trả về URL ảnh"
        }
    }
}

final class CloudinaryImageUploader {
    let cloudName: String
    let uploadPreset: String
    let folder: String
    private let session: URLSession

    init(cloudName: String, uploadPreset: String, folder: String, session: URLSession = .shared) {
        self.cloudName = cloudName
        self.uploadPreset = uploadPreset
        self.folder = folder
        self.session = session
    }

    static func resQ(folder: String) -> CloudinaryImageUploader {
        CloudinaryImageUploader(
            cloudName: "dezgwdrfs",
            uploadPreset: "ResQ_SOS",
            folder: folder
        )
    }

    func upload(image: UIImage, fileNamePrefix: String = "image") async throws -> String {
        guard let imageData = normalizedJPEGData(from: image) else {
            throw CloudinaryImageUploadError.invalidImageData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload") else {
            throw CloudinaryImageUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        request.httpBody = makeBody(
            boundary: boundary,
            uploadPreset: uploadPreset,
            folder: folder,
            fileData: imageData,
            fileName: "\(fileNamePrefix)_\(Int(Date().timeIntervalSince1970)).jpg"
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudinaryImageUploadError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw CloudinaryImageUploadError.uploadFailed(statusCode: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(CloudinaryUploadResponse.self, from: data)
        guard !decoded.secure_url.isEmpty else {
            throw CloudinaryImageUploadError.missingURL
        }
        return decoded.secure_url
    }

    private func normalizedJPEGData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 2048
        let largest = max(image.size.width, image.size.height)

        guard largest > maxDimension else {
            return image.jpegData(compressionQuality: 0.82)
        }

        let scale = maxDimension / largest
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func makeBody(
        boundary: String,
        uploadPreset: String,
        folder: String,
        fileData: Data,
        fileName: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"upload_preset\"\(lineBreak)\(lineBreak)")
        append("\(uploadPreset)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"folder\"\(lineBreak)\(lineBreak)")
        append("\(folder)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)")
        append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(fileData)
        append(lineBreak)

        append("--\(boundary)--\(lineBreak)")
        return body
    }
}
