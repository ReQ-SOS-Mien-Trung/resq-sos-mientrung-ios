import Foundation
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

/// A wrapper that routes generation to Apple Intelligence (`FoundationModels`) when available,
/// and falls back to a lightweight on-device Intent matcher when unavailable.
///
/// Notes:
/// - `FoundationModels` availability depends on device eligibility and whether Apple Intelligence is enabled.
/// - A `LanguageModelSession` can only process one request at a time.
actor FoundationModel {
    
    enum ModelError: Error {
        case notAvailable(String)
        case busy
        case inferenceFailed(String)
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private let systemModel = SystemLanguageModel.default

    @available(iOS 26.0, *)
    private var session: LanguageModelSession?
#endif
    
    // Knowledge Base Structure
    private struct Intent {
        let id: String
        let keywords: Set<String>
        let response: String
    }
    
    // Pre-defined "Knowledge" for the system to retrieve from
    private let intents: [Intent] = [
        Intent(
            id: "flood_safety",
            keywords: ["lũ", "lụt", "ngập", "nước", "dâng", "chảy", "siết"],
            response: "⚠️ AN TOÀN LŨ LỤT:\n1. Ngắt ngay nguồn điện.\n2. Di chuyển đến nơi cao ráo.\n3. Tránh xa vùng nước chảy siết.\n4. Mặc áo phao nếu có thể."
        ),
        Intent(
            id: "landslide",
            keywords: ["sạt", "lở", "đất", "đồi", "núi", "nứt", "rung"],
            response: "⛰️ CẢNH BÁO SẠT LỞ:\n- Quan sát vết nứt trên tường/đất.\n- Nếu thấy cây nghiêng hoặc tiếng động lạ, SƠ TÁN NGAY.\n- Tránh xa chân đồi/núi khi mưa lớn."
        ),
        Intent(
            id: "sos_emergency",
            keywords: ["sos", "cứu", "khẩn", "cấp", "giúp", "nạn", "chết", "nguy"],
            response: "🆘 TÍN HIỆU CẤP CỨU:\nHãy nhấn nút SOS màu đỏ trên màn hình để phát toạ độ GPS của bạn qua mạng Mesh cho các đội cứu hộ gần nhất."
        ),
        Intent(
            id: "preparation",
            keywords: ["chuẩn", "bị", "đồ", "túi", "mang", "gì", "dự", "trữ"],
            response: "🎒 TÚI KHẨN CẤP CẦN CÓ:\n1. Nước uống & lương thực khô (3 ngày).\n2. Đèn pin & pin dự phòng.\n3. Thuốc men cơ bản.\n4. Giấy tờ quan trọng (bọc nilon).\n5. Còi cứu hộ."
        ),
        Intent(
            id: "storm",
            keywords: ["bão", "gió", "giật", "mưa", "to"],
            response: "🌀 ỨNG PHÓ BÃO:\n- Chằng chống nhà cửa.\n- Chặt tỉa cành cây lớn.\n- Không ra đường khi bão đổ bộ.\n- Tránh xa cửa kính."
        )
    ]
    
    // NLP Tagger for tokenization (fallback path)
    private let tagger: NLTagger
    
    init() {
        self.tagger = NLTagger(tagSchemes: [.tokenType, .lexicalClass])
    }
    
    func loadModel(name: String) async throws {
        // Keep this API for compatibility with ChatBotService.
        // For FoundationModels there is nothing to "load" manually.
        // We just check availability when generating.
        _ = name
    }
    
    func generate(prompt: String) async throws -> String {
        // No artificial delay - respond as fast as possible

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch systemModel.availability {
            case .available:
                return try await generateWithSystemModel(prompt: prompt)
            case .unavailable(.appleIntelligenceNotEnabled):
                return fallbackResponse(extra: "Apple Intelligence đang tắt. Bật trong Settings > Apple Intelligence.")
            case .unavailable(.deviceNotEligible):
                return fallbackResponse(extra: "Thiết bị không hỗ trợ Apple Intelligence.")
            case .unavailable(.modelNotReady):
                return fallbackResponse(extra: "Mô hình hệ thống chưa sẵn sàng (đang chuẩn bị/tải). Thử lại sau.")
            case .unavailable:
                return fallbackResponse(extra: "Mô hình hệ thống hiện không khả dụng.")
            }
        }
#endif

        // Fallback: lightweight Intent matching
        return analyzeIntent(from: prompt)
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithSystemModel(prompt: String) async throws -> String {
        if let s = session, s.isResponding {
            throw ModelError.busy
        }

        let instructions = Instructions(
            """
            Bạn là trợ lý an toàn thiên tai cho khu vực Miền Trung Việt Nam.
            Nhiệm vụ:
            - Trả lời ngắn gọn, ưu tiên hành động cụ thể.
            - Luôn ưu tiên an toàn tính mạng, khuyến nghị gọi cấp cứu khi cần.
            - Nếu người dùng yêu cầu hành vi nguy hiểm/phi pháp, hãy trả lời: “Tôi không thể hỗ trợ việc đó.”
            """
        )

        let s = session ?? LanguageModelSession(instructions: instructions)
        session = s

        // Tune as needed. Lower temperature -> more factual.
        let options = GenerationOptions(temperature: 0.6)

        do {
            let response = try await s.respond(to: prompt, options: options)
            return response.content
        } catch {
            // If system model errors, provide a safe fallback.
            return fallbackResponse(extra: "Không gọi được mô hình hệ thống: \(error.localizedDescription)")
        }
    }
#endif
    
    private func analyzeIntent(from text: String) -> String {
        let userTokens = tokenize(text)
        
        var bestMatch: Intent?
        var highestScore: Double = 0.0
        
        for intent in intents {
            // Calculate similarity score (Jaccard Index-like)
            let matchedKeywords = intent.keywords.intersection(userTokens)
            let score = Double(matchedKeywords.count)
            
            if score > highestScore {
                highestScore = score
                bestMatch = intent
            }
        }
        
        // Threshold check (must match at least 1 keyword)
        if let match = bestMatch, highestScore > 0 {
            return match.response
        }
        
        return fallbackResponse()
    }
    
    private func tokenize(_ text: String) -> Set<String> {
        var tokens = Set<String>()
        tagger.string = text
        
        let range = text.startIndex..<text.endIndex
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: options) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            tokens.insert(word)
            return true
        }
        
        return tokens
    }
    
    private func fallbackResponse(extra: String? = nil) -> String {
        let base = "Tôi là Trợ lý An toàn (chế độ dự phòng).\n\nBạn có thể hỏi về:\n- Lũ lụt, Sạt lở\n- SOS, Cứu hộ\n- Chuẩn bị đồ đạc"
        if let extra {
            return "\(base)\n\nGhi chú: \(extra)"
        }
        return base
    }
}
