import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Availability

nonisolated enum VoiceSOSAIAvailabilityState: Equatable, Sendable {
    case available
    case unavailable
}

nonisolated struct VoiceSOSAIAvailability: Equatable, Sendable {
    let state: VoiceSOSAIAvailabilityState
    let message: String?

    var isAvailable: Bool {
        state == .available
    }

    static let available = VoiceSOSAIAvailability(state: .available, message: nil)

    static func unavailable(_ message: String) -> VoiceSOSAIAvailability {
        VoiceSOSAIAvailability(state: .unavailable, message: message)
    }
}

nonisolated enum VoiceSOSAvailability {
    nonisolated static func current() -> VoiceSOSAIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable("Apple Intelligence đang tắt. Vui lòng bật Apple Intelligence để dùng Voice SOS.")
            case .unavailable(.deviceNotEligible):
                return .unavailable("Thiết bị này không hỗ trợ AI trên thiết bị cho Voice SOS.")
            case .unavailable(.modelNotReady):
                return .unavailable("AI trên thiết bị chưa sẵn sàng. Vui lòng thử lại sau khi hệ thống tải/chuẩn bị model xong.")
            case .unavailable:
                return .unavailable("AI trên thiết bị hiện không khả dụng.")
            }
        }
        #endif

        return .unavailable("Voice SOS cần AI trên thiết bị trên thiết bị hỗ trợ Apple Intelligence.")
    }

    nonisolated static func shouldShowVoiceSOSButton(status: VoiceSOSAIAvailability = current()) -> Bool {
        status.isAvailable
    }
}

// MARK: - Conversation Payload

nonisolated struct VoiceConversationTurn: Codable, Equatable, Sendable {
    let role: String
    let text: String
}

nonisolated struct VoiceSOSPeopleCountDraft: Codable, Equatable, Sendable {
    var adults: Int = 0
    var children: Int = 0
    var elderly: Int = 0
    var total: Int = 0

    var effectiveTotal: Int {
        let parts = max(0, adults) + max(0, children) + max(0, elderly)
        return max(max(0, total), parts)
    }
}

nonisolated struct VoiceSOSVictimDraft: Codable, Equatable, Identifiable, Sendable {
    var id: String { personId ?? "\(personType ?? "ADULT")-\(index ?? 0)-\(name ?? "")" }

    var personId: String?
    var name: String?
    var personType: String?
    var index: Int?
    var phone: String?
    var isInjured: Bool?
    var medicalIssues: [String] = []

    var resolvedPersonType: Person.PersonType {
        switch normalizedKey(personType) {
        case Person.PersonType.child.rawValue:
            return .child
        case Person.PersonType.elderly.rawValue:
            return .elderly
        default:
            return .adult
        }
    }
}

nonisolated struct VoiceSOSGroupNeedsDraft: Codable, Equatable, Sendable {
    var supplies: [String] = []
    var otherSupplyDescription: String?
    var waterDescription: String?
    var foodDescription: String?
    var medicineDescription: String?
    var clothingDescription: String?
    var blanketDescription: String?
    var medicineConditions: [String] = []
    var medicalNeeds: [String] = []
    var medicalDescription: String?

    var hasContent: Bool {
        !supplies.isEmpty ||
            otherSupplyDescription.voiceSOSTrimmedNil != nil ||
            waterDescription.voiceSOSTrimmedNil != nil ||
            foodDescription.voiceSOSTrimmedNil != nil ||
            medicineDescription.voiceSOSTrimmedNil != nil ||
            clothingDescription.voiceSOSTrimmedNil != nil ||
            blanketDescription.voiceSOSTrimmedNil != nil ||
            !medicineConditions.isEmpty ||
            !medicalNeeds.isEmpty ||
            medicalDescription.voiceSOSTrimmedNil != nil
    }

    var combinedFreeText: String? {
        [
            otherSupplyDescription.voiceSOSTrimmedNil,
            waterDescription.voiceSOSTrimmedNil.map { "Nước: \($0)" },
            foodDescription.voiceSOSTrimmedNil.map { "Thực phẩm: \($0)" },
            medicineDescription.voiceSOSTrimmedNil.map { "Thuốc/y tế: \($0)" },
            clothingDescription.voiceSOSTrimmedNil.map { "Quần áo: \($0)" },
            blanketDescription.voiceSOSTrimmedNil.map { "Chăn mền: \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: " | ")
        .voiceSOSTrimmedNil
    }
}

nonisolated struct VoiceSOSDraft: Codable, Equatable, Sendable {
    var selectedTypes: [String] = []
    var peopleCount: VoiceSOSPeopleCountDraft = VoiceSOSPeopleCountDraft()
    var victims: [VoiceSOSVictimDraft] = []
    var situation: String?
    var situationDescription: String?
    var hasInjured: Bool?
    var medicalIssues: [String] = []
    var medicalDescription: String?
    var othersAreStable: Bool?
    var canMove: Bool?
    var groupNeeds: VoiceSOSGroupNeedsDraft = VoiceSOSGroupNeedsDraft()
    var missingFields: [String] = []
    var nextQuestion: String?
    var address: String?
    var readyToSend: Bool = false

    static let empty = VoiceSOSDraft()

    @MainActor
    var summaryLines: [(label: String, value: String)] {
        var lines: [(String, String)] = []

        let types = resolvedTypes(applyDefaults: false)
        if !types.isEmpty {
            let title = types
                .sorted { $0.rawValue < $1.rawValue }
                .map(\.title)
                .joined(separator: " + ")
            lines.append(("Loại SOS", title))
        }

        let count = resolvedPeopleCount(applyDefaults: false)
        if count.total > 0 {
            var parts: [String] = []
            if count.adults > 0 { parts.append("\(count.adults) người lớn") }
            if count.children > 0 { parts.append("\(count.children) trẻ em") }
            if count.elderly > 0 { parts.append("\(count.elderly) người già") }
            lines.append(("Số người", parts.isEmpty ? "\(count.total) người" : parts.joined(separator: ", ")))
        }

        let names = victims.compactMap { $0.name.voiceSOSTrimmedNil }
        if !names.isEmpty {
            lines.append(("Nạn nhân", names.joined(separator: ", ")))
        }

        if let situation = normalizedSituation {
            let description = situationDescription.voiceSOSTrimmedNil
            let value = description.map { "\(RescueSituation.title(for: situation)) - \($0)" }
                ?? RescueSituation.title(for: situation)
            lines.append(("Tình huống", value))
        } else if let description = situationDescription.voiceSOSTrimmedNil {
            lines.append(("Tình huống", description))
        }

        if let hasInjured {
            lines.append(("Thương tích", hasInjured ? "Có người bị thương" : "Chưa ghi nhận bị thương"))
        }

        let supplies = normalizedSupplies
        if !supplies.isEmpty || groupNeeds.combinedFreeText != nil {
            let supplyText = supplies.isEmpty
                ? "Khác"
                : supplies.map(\.title).joined(separator: ", ")
            if let description = groupNeeds.combinedFreeText {
                lines.append(("Nhu yếu phẩm", "\(supplyText) - \(description)"))
            } else {
                lines.append(("Nhu yếu phẩm", supplyText))
            }
        }

        return lines
    }

    @MainActor
    var missingFieldLabels: [String] {
        missingFields.compactMap { field in
            switch normalizedKey(field) {
            case "SOS_TYPE", "TYPE", "REQUEST_TYPE":
                return "Loại hỗ trợ"
            case "PEOPLE_COUNT", "COUNT", "VICTIMS":
                return "Số người cần hỗ trợ"
            case "SITUATION", "RESCUE_SITUATION":
                return "Tình huống cứu hộ"
            case "GROUP_NEEDS", "SUPPLIES", "RELIEF_NEEDS":
                return "Nhu cầu cứu trợ"
            case "INJURY", "INJURED", "MEDICAL":
                return "Tình trạng thương tích/y tế"
            case "LOCATION":
                return "Vị trí"
            default:
                return field.voiceSOSTrimmedNil
            }
        }
    }

    @MainActor
    var followUpQuestion: String? {
        if let nextQuestion = nextQuestion.voiceSOSTrimmedNil {
            return nextQuestion
        }

        let labels = missingFieldLabels
        guard !labels.isEmpty else { return nil }
        return "Bạn bổ sung nhanh giúp mình: \(labels.joined(separator: ", "))."
    }

    var normalizedSituation: String? {
        let key = normalizedKey(situation)
        guard RescueSituation(rawValue: key) != nil else { return nil }
        return key
    }

    var normalizedSupplies: Set<SupplyNeed> {
        Set(groupNeeds.supplies.compactMap { SupplyNeed(rawValue: normalizedKey($0)) })
    }

    nonisolated func grounded(in userTexts: [String]) -> VoiceSOSDraft {
        var draft = self
        let evidence = VoiceSOSConversationEvidence(userTexts: userTexts)

        draft.victims = draft.victims.map { victim in
            evidence.groundedVictim(victim, fallbackMedicalIssues: [])
        }

        draft.medicalIssues = evidence.groundedMedicalIssues(
            draft.medicalIssues,
            victimName: draft.victims.count == 1 ? draft.victims.first?.name : nil
        )
        draft.medicalDescription = evidence.groundedMedicalDescription(
            proposed: draft.medicalDescription,
            fallbackMedicalIssues: draft.medicalIssues,
            victimName: draft.victims.count == 1 ? draft.victims.first?.name : nil
        )

        draft.victims = draft.victims.enumerated().map { index, victim in
            let fallbackIssues = draft.victims.count == 1 ? draft.medicalIssues : []
            var groundedVictim = evidence.groundedVictim(victim, fallbackMedicalIssues: fallbackIssues)
            if groundedVictim.medicalIssues.isEmpty,
               draft.victims.count == 1,
               let medicalDescription = draft.medicalDescription.voiceSOSTrimmedNil {
                groundedVictim.medicalIssues = [medicalDescription]
            }
            if groundedVictim.name == nil, index == 0, draft.victims.count == 1,
               let recoveredName = victim.name.voiceSOSTrimmedNil,
               evidence.containsFragment(recoveredName) {
                groundedVictim.name = recoveredName
            }
            return groundedVictim
        }

        draft.groupNeeds = evidence.groundedGroupNeeds(draft.groupNeeds)
        draft.situation = evidence.groundedSituation(draft.situation)
        draft.situationDescription = evidence.groundedSituationDescription(
            proposed: draft.situationDescription,
            situation: draft.situation
        )
        draft.address = evidence.groundedAddress(
            draft.address,
            victimNames: draft.victims.compactMap { $0.name.voiceSOSTrimmedNil }
        )
        draft.canMove = evidence.groundedCanMove()
        draft.othersAreStable = evidence.groundedOthersAreStable(
            peopleCount: max(draft.peopleCount.effectiveTotal, draft.victims.count)
        )
        draft.hasInjured = evidence.groundedHasInjured(
            proposed: draft.hasInjured,
            victims: draft.victims,
            medicalIssues: draft.medicalIssues,
            medicalDescription: draft.medicalDescription
        )
        draft.peopleCount = evidence.groundedPeopleCount(
            draft.peopleCount,
            victims: draft.victims
        )
        draft.selectedTypes = evidence.groundedSelectedTypes(
            rawTypes: draft.selectedTypes,
            situation: draft.situation,
            hasInjured: draft.hasInjured,
            medicalIssues: draft.medicalIssues,
            medicalDescription: draft.medicalDescription,
            groupNeeds: draft.groupNeeds
        )
        draft.normalizeReadiness()
        return draft
    }

    nonisolated func resolvedTypes(applyDefaults: Bool) -> Set<SOSType> {
        var result = Set<SOSType>()

        for rawType in selectedTypes {
            let key = normalizedKey(rawType)
            if key == "BOTH" {
                result.insert(.rescue)
                result.insert(.relief)
            } else if key == "MEDICAL" {
                result.insert(.rescue)
            } else if let type = SOSType(rawValue: key) {
                result.insert(type)
            }
        }

        if normalizedSituation != nil || hasInjured == true || !medicalIssues.isEmpty || medicalDescription.voiceSOSTrimmedNil != nil {
            result.insert(.rescue)
        }

        if groupNeeds.hasContent {
            result.insert(.relief)
        }

        if result.isEmpty && applyDefaults {
            result.insert(.rescue)
        }

        return result
    }

    nonisolated func resolvedPeopleCount(applyDefaults: Bool) -> PeopleCount {
        var adults = max(0, peopleCount.adults)
        var children = max(0, peopleCount.children)
        var elderly = max(0, peopleCount.elderly)

        if adults + children + elderly == 0 {
            for victim in victims {
                switch victim.resolvedPersonType {
                case .adult:
                    adults += 1
                case .child:
                    children += 1
                case .elderly:
                    elderly += 1
                }
            }
        }

        let parts = adults + children + elderly
        let total = max(0, peopleCount.total)
        if total > parts {
            adults += total - parts
        }

        if adults + children + elderly == 0 && applyDefaults {
            adults = 1
        }

        return PeopleCount(adults: adults, children: children, elderly: elderly)
    }

    private nonisolated mutating func normalizeReadiness() {
        var missing = Set(missingFields.map(normalizedKey))
        let types = resolvedTypes(applyDefaults: false)
        let count = resolvedPeopleCount(applyDefaults: false)
        let hasPeople = count.adults + count.children + count.elderly > 0
        let hasRescueSignal = normalizedSituation != nil ||
            hasInjured == true ||
            !medicalIssues.isEmpty ||
            medicalDescription.voiceSOSTrimmedNil != nil
        let hasReliefSignal = groupNeeds.hasContent

        if types.isEmpty {
            missing.insert("SOS_TYPE")
        } else {
            missing.remove("SOS_TYPE")
            missing.remove("TYPE")
            missing.remove("REQUEST_TYPE")
        }

        if !hasPeople {
            missing.insert("PEOPLE_COUNT")
        } else {
            missing.remove("PEOPLE_COUNT")
            missing.remove("COUNT")
            missing.remove("VICTIMS")
        }

        if !hasRescueSignal {
            missing.insert("SITUATION")
        } else {
            missing.remove("SITUATION")
            missing.remove("RESCUE_SITUATION")
        }

        // Bỏ phần Cứu trợ (GROUP_NEEDS) theo yêu cầu. Voice SOS giờ chỉ tập trung Giải cứu.
        missing.remove("GROUP_NEEDS")
        missing.remove("SUPPLIES")
        missing.remove("RELIEF_NEEDS")

        if address.voiceSOSTrimmedNil == nil {
            missing.insert("LOCATION")
        } else {
            missing.remove("LOCATION")
            missing.remove("ADDRESS")
        }

        if missing.contains("address") || missing.contains("ADDRESS") {
            missing.remove("address")
            missing.remove("ADDRESS")
            missing.insert("LOCATION")
        }
        
        missingFields = Array(missing).sorted()
        // Để đảm bảo Checklist được hoàn thành:
        // Nếu AI xác định còn trường missing, tuyệt đối KHÔNG cho phép gửi.
        if !missingFields.isEmpty {
            readyToSend = false
        } else if nextQuestion.voiceSOSTrimmedNil != nil {
            readyToSend = false
        } else if !hasPeople || (!hasRescueSignal && !hasReliefSignal) {
            // Safety net: kể cả khi AI nghĩ là đủ, nhưng thiếu basic info thì cũng chặn.
            readyToSend = false
        }
    }

    @MainActor
    func makeSOSFormData(
        autoInfo: AutoCollectedInfo,
        conversationUserTexts: [String],
        applyDefaults: Bool = true
    ) -> SOSFormData {
        let draft = grounded(in: conversationUserTexts)
        let formData = SOSFormData()
        formData.reportingTarget = .self
        formData.autoInfo = autoInfo
        formData.selectedTypes = draft.resolvedTypes(applyDefaults: applyDefaults)
        formData.sharedPeopleCount = draft.resolvedPeopleCount(applyDefaults: applyDefaults)
        formData.syncPeopleCount()

        if let address = draft.address.voiceSOSTrimmedNil {
            formData.addressQuery = address
            formData.resolvedAddress = address
        }

        draft.applyVictims(to: formData)

        if formData.needsRescueStep {
            formData.rescueData.situation = draft.normalizedSituation
            formData.rescueData.otherSituationDescription = draft.situationDescription.voiceSOSTrimmedNil ?? ""
            formData.rescueData.hasInjured = draft.hasInjured ?? draft.victims.contains { $0.isInjured == true }
            formData.rescueData.othersAreStable = draft.othersAreStable == true
            formData.rescueData.canMove = draft.canMove
            formData.rescueData.otherMedicalDescription = draft.medicalDescription.voiceSOSTrimmedNil ?? ""
            draft.applyMedicalDetails(to: formData)
        }

        if formData.needsReliefStep {
            formData.reliefData.supplies = draft.normalizedSupplies
            if formData.reliefData.supplies.isEmpty && draft.groupNeeds.combinedFreeText != nil {
                formData.reliefData.supplies.insert(.other)
            }
            formData.reliefData.otherSupplyDescription = draft.groupNeeds.combinedFreeText ?? ""
            formData.reliefData.medicineConditions = Set(draft.groupNeeds.medicineConditions.compactMap {
                MedicineCondition(rawValue: normalizedKey($0))
            })
            formData.reliefData.medicalNeeds = Set(draft.groupNeeds.medicalNeeds.compactMap {
                MedicalSupportNeed(rawValue: normalizedKey($0))
            })
            formData.reliefData.medicalDescription = draft.groupNeeds.medicalDescription.voiceSOSTrimmedNil ?? ""
        }

        let userTexts = conversationUserTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var userQuote = "[Voice SOS] Lời nạn nhân: " + userTexts.joined(separator: " | ")
        if let addr = draft.address, !addr.isEmpty {
            userQuote += " | Địa chỉ/Vị trí: \(addr)"
        }
        if !userTexts.isEmpty {
            formData.additionalDescription = userQuote
        }

        return formData
    }

    @MainActor
    private func applyVictims(to formData: SOSFormData) {
        var remainingPeopleByType = Dictionary(grouping: formData.sharedPeople, by: \.type)

        for victim in victims {
            guard let name = victim.name.voiceSOSTrimmedNil else { continue }
            let type = victim.resolvedPersonType
            if var remaining = remainingPeopleByType[type], let person = remaining.first {
                formData.updatePersonName(name, for: person.id)
                remaining.removeFirst()
                remainingPeopleByType[type] = remaining
            }
        }
    }

    @MainActor
    private func applyMedicalDetails(to formData: SOSFormData) {
        var affectedPersonIds = Set<String>()
        var remainingPeopleByType = Dictionary(grouping: formData.sharedPeople, by: \.type)
        var aggregatedOtherDescriptions: [String] = []

        for victim in victims {
            guard victim.isInjured == true || !victim.medicalIssues.isEmpty else { continue }
            let type = victim.resolvedPersonType
            guard var remaining = remainingPeopleByType[type], let person = remaining.first else { continue }
            remaining.removeFirst()
            remainingPeopleByType[type] = remaining

            affectedPersonIds.insert(person.id)
            let issues = normalizedMedicalIssues(victim.medicalIssues)
            let otherDescription = freeTextMedicalDescription(
                from: victim.medicalIssues,
                preferredFallback: victim.name.voiceSOSTrimmedNil
            )
            if let otherDescription {
                let label = person.customName.voiceSOSTrimmedNil ?? person.displayName
                aggregatedOtherDescriptions.append("\(label): \(otherDescription)")
            }
            formData.rescueData.medicalInfoByPerson[person.id] = PersonMedicalInfo(
                personId: person.id,
                medicalIssues: Set(issues.isEmpty ? [MedicalIssue.other.rawValue] : issues),
                otherDescription: otherDescription ?? ""
            )
        }

        if affectedPersonIds.isEmpty && formData.rescueData.hasInjured, let firstPerson = formData.sharedPeople.first {
            affectedPersonIds.insert(firstPerson.id)
            let issues = normalizedMedicalIssues(medicalIssues)
            let otherDescription = freeTextMedicalDescription(from: medicalIssues)
            if let otherDescription {
                aggregatedOtherDescriptions.append(otherDescription)
            }
            formData.rescueData.medicalInfoByPerson[firstPerson.id] = PersonMedicalInfo(
                personId: firstPerson.id,
                medicalIssues: Set(issues.isEmpty ? [MedicalIssue.other.rawValue] : issues),
                otherDescription: otherDescription ?? ""
            )
        }

        formData.rescueData.injuredPersonIds = affectedPersonIds
        if !affectedPersonIds.isEmpty {
            formData.rescueData.hasInjured = true
        }
        let combinedOtherDescription = voiceSOSUniqueStrings(
            [formData.rescueData.otherMedicalDescription] + aggregatedOtherDescriptions
        ).joined(separator: " | ").voiceSOSTrimmedNil
        formData.rescueData.otherMedicalDescription = combinedOtherDescription ?? ""
    }

    private func normalizedMedicalIssues(_ rawIssues: [String]) -> [String] {
        voiceSOSUniqueStrings(
            rawIssues.compactMap { raw in
                voiceSOSNormalizedMedicalIssue(from: raw)
            }
        )
    }

    private func freeTextMedicalDescription(
        from rawIssues: [String],
        preferredFallback: String? = nil
    ) -> String? {
        let freeTextIssues = voiceSOSUniqueStrings(
            rawIssues.compactMap { raw in
                let trimmed = raw.voiceSOSTrimmedNil
                guard let trimmed else { return nil }
                return voiceSOSNormalizedMedicalIssue(from: trimmed) == nil ? trimmed : nil
            }
        )
        if !freeTextIssues.isEmpty {
            let joined = freeTextIssues.joined(separator: "; ").voiceSOSTrimmedNil
            if let joined, let preferredFallback = preferredFallback?.voiceSOSTrimmedNil,
               joined.hasPrefix(preferredFallback) {
                let remainder = joined.dropFirst(preferredFallback.count)
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :-,"))
                return remainder.voiceSOSTrimmedNil ?? joined
            }
            return joined
        }
        return nil
    }
}

// MARK: - Provider

nonisolated enum VoiceSOSUnderstandingError: LocalizedError {
    case unavailable(String)
    case busy
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        case .busy:
            return "AI trên thiết bị đang xử lý. Vui lòng thử lại sau."
        case .failed(let message):
            return message
        }
    }
}

nonisolated protocol VoiceSOSUnderstandingProvider: Sendable {
    func updateDraft(
        conversationHistory: [VoiceConversationTurn],
        currentDraft: VoiceSOSDraft
    ) async throws -> VoiceSOSDraft
}

actor FoundationModelsVoiceSOSUnderstandingProvider: VoiceSOSUnderstandingProvider {
    #if canImport(FoundationModels)
    private var _session: Any?

    @available(iOS 26.0, *)
    private var session: LanguageModelSession? {
        get { _session as? LanguageModelSession }
        set { _session = newValue }
    }
    #endif

    func updateDraft(
        conversationHistory: [VoiceConversationTurn],
        currentDraft: VoiceSOSDraft
    ) async throws -> VoiceSOSDraft {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = VoiceSOSAvailability.current()
            guard availability.isAvailable else {
                throw VoiceSOSUnderstandingError.unavailable(
                    availability.message ?? "AI trên thiết bị hiện không khả dụng."
                )
            }
            return try await generateWithFoundationModels(
                conversationHistory: conversationHistory,
                currentDraft: currentDraft
            )
        }
        #endif

        throw VoiceSOSUnderstandingError.unavailable("Voice SOS cần AI trên thiết bị hỗ trợ Apple Intelligence.")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(
        conversationHistory: [VoiceConversationTurn],
        currentDraft: VoiceSOSDraft
    ) async throws -> VoiceSOSDraft {
        if let activeSession = session, activeSession.isResponding {
            throw VoiceSOSUnderstandingError.busy
        }

        let instructions = Instructions(
            """
            Bạn là AI tiếp nhận thông tin SOS CỨU HỘ (RESCUE). Chỉ tập trung vào việc giải cứu người.
            
            CHECKLIST: 1.Tình huống? 2.Số lượng người? 3.Danh tính? 4.Y tế? 5.Địa chỉ?
            
            QUY TẮC:
            - TUYỆT ĐỐI KHÔNG tự bịa thông tin giả. Chỉ trích xuất từ payload.
            - Địa chỉ (address): Trích xuất bất cứ thứ gì người dùng nói về vị trí, số nhà, tên đường, khu vực vào trường 'address'.
            - missingFields: Chú ý ghi nhận "LOCATION" nếu chưa biết địa chỉ.
            - Luôn đặt selectedTypes là ["RESCUE"]. Bỏ qua nhu yếu phẩm/cứu trợ.
            - Nếu thiếu thông tin cứu hộ, set readyToSend=false và đặt câu hỏi ở nextQuestion.
            """
        )

        // KHÔNG lưu lại session để tránh việc dồn nén history gây quá tải context window (4096 tokens).
        // Vì chúng ta đã gửi conversationHistory trong payload JSON rồi.
        let activeSession = LanguageModelSession(instructions: instructions)

        let prompt = makePrompt(
            conversationHistory: conversationHistory,
            currentDraft: currentDraft
        )
        
        do {
            let response = try await activeSession.respond(
                to: prompt,
                generating: GeneratedVoiceSOSDraft.self
            )
            return response.content.voiceSOSDraft
        } catch {
            throw VoiceSOSUnderstandingError.failed(error.localizedDescription)
        }
    }

    @available(iOS 26.0, *)
    private func makePrompt(
        conversationHistory: [VoiceConversationTurn],
        currentDraft: VoiceSOSDraft
    ) -> String {
        let payload = VoiceSOSUnderstandingPromptPayload(
            conversationHistory: Array(conversationHistory.suffix(10)),
            currentDraft: currentDraft
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payloadText = (try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        Hãy cập nhật draft SOS dựa trên hội thoại. Chỉ trả về JSON theo schema.
        readyToSend=true CHỈ KHI ĐÃ HỎI ĐỦ CHECKLIST.
        Nếu thiếu thông tin trong checklist, đặt readyToSend=false và đặt câu hỏi gom các ý còn thiếu vào nextQuestion.

        Payload:
        \(payloadText)
        """
    }
    #endif
}

// MARK: - Gemini Online Provider

private nonisolated struct GeminiVoiceSOSAPIError: Error {
    let model: String
    let statusCode: Int
    let body: String

    var isModelNotFound: Bool {
        statusCode == 404
    }

    var message: String {
        "Gemini API Error (\(model), HTTP \(statusCode)): \(body)"
    }
}

private nonisolated struct GeminiVoiceSOSDraftPayload: Decodable {
    var selectedTypes: [String]?
    var peopleCount: GeminiVoiceSOSPeopleCountPayload?
    var victims: [GeminiVoiceSOSVictimPayload]?
    var situation: String?
    var situationDescription: String?
    var hasInjured: Bool?
    var medicalIssues: [String]?
    var medicalDescription: String?
    var othersAreStable: Bool?
    var canMove: Bool?
    var groupNeeds: GeminiVoiceSOSGroupNeedsPayload?
    var missingFields: [String]?
    var nextQuestion: String?
    var address: String?
    var readyToSend: Bool?

    var voiceSOSDraft: VoiceSOSDraft {
        VoiceSOSDraft(
            selectedTypes: selectedTypes ?? [],
            peopleCount: peopleCount?.voiceSOSPeopleCount ?? VoiceSOSPeopleCountDraft(),
            victims: victims?.map(\.voiceSOSVictim) ?? [],
            situation: situation,
            situationDescription: situationDescription,
            hasInjured: hasInjured,
            medicalIssues: medicalIssues ?? [],
            medicalDescription: medicalDescription,
            othersAreStable: othersAreStable,
            canMove: canMove,
            groupNeeds: groupNeeds?.voiceSOSGroupNeeds ?? VoiceSOSGroupNeedsDraft(),
            missingFields: missingFields ?? [],
            nextQuestion: nextQuestion,
            address: address,
            readyToSend: readyToSend ?? false
        )
    }
}

private nonisolated struct GeminiVoiceSOSPeopleCountPayload: Decodable {
    var adults: Int?
    var children: Int?
    var elderly: Int?
    var total: Int?

    var voiceSOSPeopleCount: VoiceSOSPeopleCountDraft {
        VoiceSOSPeopleCountDraft(
            adults: max(0, adults ?? 0),
            children: max(0, children ?? 0),
            elderly: max(0, elderly ?? 0),
            total: max(0, total ?? 0)
        )
    }
}

private nonisolated struct GeminiVoiceSOSVictimPayload: Decodable {
    var personId: String?
    var name: String?
    var personType: String?
    var index: Int?
    var phone: String?
    var isInjured: Bool?
    var medicalIssues: [String]?

    var voiceSOSVictim: VoiceSOSVictimDraft {
        VoiceSOSVictimDraft(
            personId: personId,
            name: name,
            personType: personType,
            index: index,
            phone: phone,
            isInjured: isInjured,
            medicalIssues: medicalIssues ?? []
        )
    }
}

private nonisolated struct GeminiVoiceSOSGroupNeedsPayload: Decodable {
    var supplies: [String]?
    var otherSupplyDescription: String?
    var waterDescription: String?
    var foodDescription: String?
    var medicineDescription: String?
    var clothingDescription: String?
    var blanketDescription: String?
    var medicineConditions: [String]?
    var medicalNeeds: [String]?
    var medicalDescription: String?

    var voiceSOSGroupNeeds: VoiceSOSGroupNeedsDraft {
        VoiceSOSGroupNeedsDraft(
            supplies: supplies ?? [],
            otherSupplyDescription: otherSupplyDescription,
            waterDescription: waterDescription,
            foodDescription: foodDescription,
            medicineDescription: medicineDescription,
            clothingDescription: clothingDescription,
            blanketDescription: blanketDescription,
            medicineConditions: medicineConditions ?? [],
            medicalNeeds: medicalNeeds ?? [],
            medicalDescription: medicalDescription
        )
    }
}

actor GeminiVoiceSOSUnderstandingProvider: VoiceSOSUnderstandingProvider {
    nonisolated static let defaultModelCandidates = [
        "gemini-2.5-flash",
        "gemini-3-flash-preview"
    ]

    private let modelCandidates: [String]

    init(modelCandidates: [String] = GeminiVoiceSOSUnderstandingProvider.defaultModelCandidates) {
        self.modelCandidates = modelCandidates
    }

    func updateDraft(
        conversationHistory: [VoiceConversationTurn],
        currentDraft: VoiceSOSDraft
    ) async throws -> VoiceSOSDraft {
        let apiKey = KeyManager.gemini
        guard !apiKey.isEmpty else {
            throw VoiceSOSUnderstandingError.unavailable("Chưa cấu hình Gemini API Key.")
        }

        let instructions = """
            Bạn là AI tiếp nhận thông tin SOS CỨU HỘ (RESCUE). Chỉ tập trung vào việc giải cứu người.
            Nhiệm vụ: Lấy đủ thông tin theo CHECKLIST.
            CHECKLIST: 1.Tình huống? 2.Số lượng người? 3.Danh tính? 4.Y tế? 5.Địa chỉ?
            
            QUY TẮC:
            - TUYỆT ĐỐI KHÔNG tự bịa thông tin giả. Chỉ trích xuất từ hội thoại.
            - Địa chỉ (address): Trích xuất thông tin vị trí vào trường 'address'.
            - missingFields: Phải có "LOCATION" nếu chưa biết địa chỉ.
            - Luôn đặt selectedTypes là ["RESCUE"].
            - Nếu thiếu thông tin, set readyToSend=false và đặt câu hỏi gom các ý thiếu vào nextQuestion.
            - Trả về JSON theo đúng schema.
            - Chỉ trả về object JSON thuần, không bọc Markdown.
            """

        let historyText = conversationHistory.suffix(10).map { "\($0.role.uppercased()): \($0.text)" }.joined(separator: "\n")
        let draftJSON = (try? JSONEncoder().encode(currentDraft)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let prompt = """
            \(instructions)
            
            DRAFT HIỆN TẠI:
            \(draftJSON)
            
            HỘI THOẠI GẦN ĐÂY:
            \(historyText)
            """

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        let httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        var lastModelError: GeminiVoiceSOSAPIError?
        for model in modelCandidates {
            do {
                return try await generateDraft(
                    model: model,
                    apiKey: apiKey,
                    httpBody: httpBody
                )
            } catch let error as GeminiVoiceSOSAPIError where error.isModelNotFound {
                lastModelError = error
                continue
            } catch let error as GeminiVoiceSOSAPIError {
                throw VoiceSOSUnderstandingError.failed(error.message)
            }
        }

        if let lastModelError {
            throw VoiceSOSUnderstandingError.failed(lastModelError.message)
        }

        throw VoiceSOSUnderstandingError.failed("Không có Gemini model khả dụng cho Voice SOS.")
    }

    private func generateDraft(
        model: String,
        apiKey: String,
        httpBody: Data
    ) async throws -> VoiceSOSDraft {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = httpBody

        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
            throw GeminiVoiceSOSAPIError(
                model: model,
                statusCode: httpResponse.statusCode,
                body: errorMsg
            )
        }

        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String
                    }
                    let parts: [Part]
                }
                let content: Content?
            }
            let candidates: [Candidate]
        }

        let geminiResult = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonString = geminiResult.candidates.first?.content?.parts.first?.text,
              let jsonData = jsonString.data(using: .utf8) else {
            throw VoiceSOSUnderstandingError.failed("Không nhận được phản hồi từ Gemini.")
        }

        let decodedDraft = try JSONDecoder().decode(GeminiVoiceSOSDraftPayload.self, from: jsonData)
        return decodedDraft.voiceSOSDraft
    }
}

private nonisolated struct VoiceSOSUnderstandingPromptPayload: Codable {
    let conversationHistory: [VoiceConversationTurn]
    let currentDraft: VoiceSOSDraft
}

private nonisolated struct VoiceSOSConversationEvidence {
    let userTexts: [String]
    private let searchableText: String

    init(userTexts: [String]) {
        self.userTexts = userTexts
            .compactMap { $0.voiceSOSTrimmedNil }
        self.searchableText = voiceSOSSearchable(self.userTexts.joined(separator: " | "))
    }

    func containsFragment(_ value: String?) -> Bool {
        let key = voiceSOSSearchable(value)
        guard !key.isEmpty else { return false }
        return searchableText.contains(key)
    }

    func groundedVictim(
        _ victim: VoiceSOSVictimDraft,
        fallbackMedicalIssues: [String]
    ) -> VoiceSOSVictimDraft {
        var grounded = victim

        if let name = grounded.name.voiceSOSTrimmedNil, containsFragment(name) == false {
            grounded.name = nil
        }

        grounded.personType = groundedPersonType(grounded.personType)
        grounded.medicalIssues = groundedMedicalIssues(
            grounded.medicalIssues,
            victimName: grounded.name,
            fallback: fallbackMedicalIssues
        )

        if !grounded.medicalIssues.isEmpty {
            grounded.isInjured = true
        } else if grounded.isInjured == true, hasInjurySignal {
            grounded.isInjured = true
        } else {
            grounded.isInjured = nil
        }

        return grounded
    }

    func groundedMedicalIssues(
        _ rawIssues: [String],
        victimName: String?,
        fallback: [String] = []
    ) -> [String] {
        let grounded = voiceSOSUniqueStrings(
            rawIssues.compactMap { rawIssue in
                guard let issue = voiceSOSSanitizedText(rawIssue) else { return nil }
                if containsFragment(issue) {
                    return issue
                }
                guard let issueKey = voiceSOSNormalizedMedicalIssue(from: issue) else { return nil }
                return hasEvidence(forMedicalIssue: issueKey) ? issue : nil
            }
        )

        if !grounded.isEmpty {
            return grounded
        }

        if let injuryClause = bestInjuryClause(victimName: victimName) {
            return [injuryClause]
        }

        return fallback
    }

    func groundedMedicalDescription(
        proposed: String?,
        fallbackMedicalIssues: [String],
        victimName: String?
    ) -> String? {
        if let proposed = voiceSOSSanitizedText(proposed), containsFragment(proposed) {
            return proposed
        }

        let freeTextIssues: [String] = fallbackMedicalIssues.compactMap { issue -> String? in
            let trimmed = issue.voiceSOSTrimmedNil
            guard let trimmed else { return nil }
            return voiceSOSNormalizedMedicalIssue(from: trimmed) == nil ? trimmed : nil
        }
        if let joined = voiceSOSUniqueStrings(freeTextIssues).joined(separator: "; ").voiceSOSTrimmedNil {
            return joined
        }

        return bestInjuryClause(victimName: victimName)
    }

    func groundedGroupNeeds(_ groupNeeds: VoiceSOSGroupNeedsDraft) -> VoiceSOSGroupNeedsDraft {
        var grounded = groupNeeds

        grounded.supplies = SupplyNeed.allCases
            .filter { supply in
                groupNeeds.supplies.contains(where: { normalizedKey($0) == supply.rawValue }) &&
                    hasEvidence(forSupply: supply)
            }
            .map(\.rawValue)

        grounded.otherSupplyDescription = groundedFreeText(
            groupNeeds.otherSupplyDescription,
            keywords: voiceSOSReliefKeywords
        )
        grounded.waterDescription = groundedFreeText(
            groupNeeds.waterDescription,
            keywords: voiceSOSKeywords(for: .water)
        )
        grounded.foodDescription = groundedFreeText(
            groupNeeds.foodDescription,
            keywords: voiceSOSKeywords(for: .food)
        )
        grounded.medicineDescription = groundedFreeText(
            groupNeeds.medicineDescription,
            keywords: voiceSOSKeywords(for: .medicine)
        )
        grounded.clothingDescription = groundedFreeText(
            groupNeeds.clothingDescription,
            keywords: voiceSOSKeywords(for: .clothes)
        )
        grounded.blanketDescription = groundedFreeText(
            groupNeeds.blanketDescription,
            keywords: voiceSOSKeywords(for: .blanket)
        )
        grounded.medicalDescription = groundedFreeText(
            groupNeeds.medicalDescription,
            keywords: voiceSOSMedicalKeywords
        )

        grounded.medicineConditions = MedicineCondition.allCases
            .filter { condition in
                groupNeeds.medicineConditions.contains(where: { normalizedKey($0) == condition.rawValue }) &&
                    hasEvidence(forMedicineCondition: condition)
            }
            .map(\.rawValue)

        grounded.medicalNeeds = MedicalSupportNeed.allCases
            .filter { need in
                groupNeeds.medicalNeeds.contains(where: { normalizedKey($0) == need.rawValue }) &&
                    hasEvidence(forMedicalSupportNeed: need)
            }
            .map(\.rawValue)

        return grounded
    }

    func groundedSituation(_ proposedSituation: String?) -> String? {
        guard let situation = RescueSituation(rawValue: normalizedKey(proposedSituation)) else { return nil }
        return hasEvidence(forSituation: situation) ? situation.rawValue : nil
    }

    func groundedSituationDescription(
        proposed: String?,
        situation: String?
    ) -> String? {
        if let proposed = voiceSOSSanitizedText(proposed), containsFragment(proposed) {
            return proposed
        }

        guard let situation = RescueSituation(rawValue: normalizedKey(situation)) else { return nil }
        return bestClause(matching: voiceSOSKeywords(for: situation))
    }

    func groundedAddress(_ proposed: String?, victimNames: [String]) -> String? {
        if let address = voiceSOSSanitizedText(proposed),
           containsFragment(address),
           voiceSOSLooksLikeAddress(address) {
            return address
        }

        // Fallback: Nếu AI không trích xuất được nhưng trong lời nói có gì đó giống địa chỉ
        if let found = bestAddressClause() {
            return found
        }

        return nil
    }

    private func bestAddressClause() -> String? {
        for text in userTexts.reversed() {
            let clauses = voiceSOSClauses(in: text)
            // Ưu tiên clause có cả số và từ khóa địa chỉ
            if let best = clauses.first(where: { 
                let searchable = voiceSOSSearchable($0)
                return searchable.contains(where: \.isNumber) && voiceSOSLocationKeywords.contains(where: searchable.contains)
            }) {
                return best
            }
            // Sau đó mới đến clause có số hoặc từ khóa
            if let matching = clauses.first(where: { voiceSOSLooksLikeAddress($0) }) {
                return matching
            }
        }
        return nil
    }

    func groundedCanMove() -> Bool? {
        if containsAny(voiceSOSCannotMoveKeywords) {
            return false
        }
        if containsAny(voiceSOSCanMoveKeywords) {
            return true
        }
        return nil
    }

    func groundedOthersAreStable(peopleCount: Int) -> Bool? {
        guard peopleCount > 1 else { return nil }
        if containsAny(voiceSOSOthersStableKeywords) {
            return true
        }
        if containsAny(voiceSOSOthersUnstableKeywords) {
            return false
        }
        return nil
    }

    func groundedHasInjured(
        proposed: Bool?,
        victims: [VoiceSOSVictimDraft],
        medicalIssues: [String],
        medicalDescription: String?
    ) -> Bool? {
        if victims.contains(where: { $0.isInjured == true || !$0.medicalIssues.isEmpty }) {
            return true
        }
        if !medicalIssues.isEmpty || medicalDescription.voiceSOSTrimmedNil != nil {
            return true
        }
        if hasInjurySignal {
            return true
        }
        return proposed == false ? false : nil
    }

    func groundedPeopleCount(
        _ peopleCount: VoiceSOSPeopleCountDraft,
        victims: [VoiceSOSVictimDraft]
    ) -> VoiceSOSPeopleCountDraft {
        let childCount = supportsChildren ? max(0, peopleCount.children) : 0
        let elderlyCount = supportsElderly ? max(0, peopleCount.elderly) : 0
        let total = max(max(0, peopleCount.total), victims.count)
        let inferredAdultCount = max(0, total - childCount - elderlyCount)

        return VoiceSOSPeopleCountDraft(
            adults: inferredAdultCount,
            children: childCount,
            elderly: elderlyCount,
            total: max(total, inferredAdultCount + childCount + elderlyCount)
        )
    }

    func groundedSelectedTypes(
        rawTypes: [String],
        situation: String?,
        hasInjured: Bool?,
        medicalIssues: [String],
        medicalDescription: String?,
        groupNeeds: VoiceSOSGroupNeedsDraft
    ) -> [String] {
        var types = Set<SOSType>()

        for rawType in rawTypes {
            switch normalizedKey(rawType) {
            case "RESCUE", "MEDICAL":
                types.insert(.rescue)
            case "RELIEF":
                types.insert(.relief)
            case "BOTH":
                types.insert(.rescue)
                types.insert(.relief)
            default:
                break
            }
        }

        let hasRescueSignal = situation != nil ||
            hasInjured == true ||
            !medicalIssues.isEmpty ||
            medicalDescription.voiceSOSTrimmedNil != nil
        if hasRescueSignal {
            types.insert(.rescue)
        }

        if groupNeeds.hasContent {
            types.insert(.relief)
        } else {
            types.remove(.relief)
        }

        return SOSType.allCases
            .filter { types.contains($0) }
            .map(\.rawValue)
    }

    private var hasInjurySignal: Bool {
        containsAny(voiceSOSMedicalKeywords)
    }

    private var supportsChildren: Bool {
        containsAny(["tre em", "em be", "be ", "dua tre", "con nho", "chau be"])
    }

    private var supportsElderly: Bool {
        containsAny(["nguoi gia", "cu gia", "cu ong", "cu ba", "ong cu", "ba cu"])
    }

    private func groundedPersonType(_ proposed: String?) -> String? {
        switch normalizedKey(proposed) {
        case Person.PersonType.child.rawValue:
            return supportsChildren ? Person.PersonType.child.rawValue : nil
        case Person.PersonType.elderly.rawValue:
            return supportsElderly ? Person.PersonType.elderly.rawValue : nil
        default:
            return nil
        }
    }

    private func groundedFreeText(_ proposed: String?, keywords: [String]) -> String? {
        guard let text = voiceSOSSanitizedText(proposed) else { return nil }
        if containsFragment(text) || containsAny(keywords) {
            return text
        }
        return nil
    }

    private func hasEvidence(forSituation situation: RescueSituation) -> Bool {
        containsAny(voiceSOSKeywords(for: situation))
    }

    private func hasEvidence(forMedicalIssue issue: String) -> Bool {
        containsAny(voiceSOSKeywords(forMedicalIssue: issue))
    }

    private func hasEvidence(forSupply supply: SupplyNeed) -> Bool {
        containsAny(voiceSOSKeywords(for: supply))
    }

    private func hasEvidence(forMedicineCondition condition: MedicineCondition) -> Bool {
        containsAny(voiceSOSKeywords(for: condition))
    }

    private func hasEvidence(forMedicalSupportNeed need: MedicalSupportNeed) -> Bool {
        containsAny(voiceSOSKeywords(for: need))
    }

    private func containsAny(_ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            searchableText.contains(keyword)
        }
    }

    private func bestInjuryClause(victimName: String?) -> String? {
        if let victimName, let victimSpecific = bestClause(
            matching: voiceSOSMedicalKeywords,
            preferredFragment: victimName
        ) {
            return voiceSOSCondensedMedicalText(victimSpecific, victimName: victimName)
        }

        return bestClause(matching: voiceSOSMedicalKeywords)
    }

    private func bestClause(
        matching keywords: [String],
        preferredFragment: String? = nil
    ) -> String? {
        let preferredKey = voiceSOSSearchable(preferredFragment)

        for text in userTexts {
            let clauses = voiceSOSClauses(in: text)
            if !preferredKey.isEmpty,
               let matchingPreferred = clauses.first(where: {
                   let key = voiceSOSSearchable($0)
                   return key.contains(preferredKey) && keywords.contains(where: key.contains)
               }) {
                return matchingPreferred.voiceSOSTrimmedNil
            }
            if let matchingClause = clauses.first(where: {
                let key = voiceSOSSearchable($0)
                return keywords.contains(where: key.contains)
            }) {
                return matchingClause.voiceSOSTrimmedNil
            }
        }

        return nil
    }
}

// MARK: - FoundationModels Guided Output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable(description: "Structured Voice SOS draft extracted from Vietnamese emergency conversation.")
nonisolated struct GeneratedVoiceSOSDraft: Codable {
    var selectedTypes: [String]
    var peopleCount: GeneratedVoiceSOSPeopleCount
    var victims: [GeneratedVoiceSOSVictim]
    var situation: String?
    var situationDescription: String?
    var hasInjured: Bool?
    var medicalIssues: [String]
    var medicalDescription: String?
    var othersAreStable: Bool?
    var canMove: Bool?
    var groupNeeds: GeneratedVoiceSOSGroupNeeds
    var missingFields: [String]
    var nextQuestion: String?
    var address: String?
    var readyToSend: Bool

    var voiceSOSDraft: VoiceSOSDraft {
        VoiceSOSDraft(
            selectedTypes: selectedTypes,
            peopleCount: peopleCount.voiceSOSPeopleCount,
            victims: victims.map(\.voiceSOSVictim),
            situation: situation,
            situationDescription: situationDescription,
            hasInjured: hasInjured,
            medicalIssues: medicalIssues,
            medicalDescription: medicalDescription,
            othersAreStable: othersAreStable,
            canMove: canMove,
            groupNeeds: groupNeeds.voiceSOSGroupNeeds,
            missingFields: missingFields,
            nextQuestion: nextQuestion,
            address: address,
            readyToSend: readyToSend
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "People count for the SOS request.")
nonisolated struct GeneratedVoiceSOSPeopleCount: Codable {
    var adults: Int
    var children: Int
    var elderly: Int
    var total: Int

    var voiceSOSPeopleCount: VoiceSOSPeopleCountDraft {
        VoiceSOSPeopleCountDraft(
            adults: max(0, adults),
            children: max(0, children),
            elderly: max(0, elderly),
            total: max(0, total)
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "One victim or affected person mentioned by the speaker.")
nonisolated struct GeneratedVoiceSOSVictim: Codable {
    var personId: String?
    var name: String?
    var personType: String?
    var index: Int?
    var phone: String?
    var isInjured: Bool?
    var medicalIssues: [String]

    var voiceSOSVictim: VoiceSOSVictimDraft {
        VoiceSOSVictimDraft(
            personId: personId,
            name: name,
            personType: personType,
            index: index,
            phone: phone,
            isInjured: isInjured,
            medicalIssues: medicalIssues
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "Relief and supply needs mentioned by the speaker.")
nonisolated struct GeneratedVoiceSOSGroupNeeds: Codable {
    var supplies: [String]
    var otherSupplyDescription: String?
    var waterDescription: String?
    var foodDescription: String?
    var medicineDescription: String?
    var clothingDescription: String?
    var blanketDescription: String?
    var medicineConditions: [String]
    var medicalNeeds: [String]
    var medicalDescription: String?

    var voiceSOSGroupNeeds: VoiceSOSGroupNeedsDraft {
        VoiceSOSGroupNeedsDraft(
            supplies: supplies,
            otherSupplyDescription: otherSupplyDescription,
            waterDescription: waterDescription,
            foodDescription: foodDescription,
            medicineDescription: medicineDescription,
            clothingDescription: clothingDescription,
            blanketDescription: blanketDescription,
            medicineConditions: medicineConditions,
            medicalNeeds: medicalNeeds,
            medicalDescription: medicalDescription
        )
    }
}
#endif

// MARK: - Helpers

private nonisolated func normalizedKey(_ rawValue: String?) -> String {
    rawValue?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased()
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "-", with: "_")
        ?? ""
}

private nonisolated let voiceSOSPlaceholderKeywords = [
    "neu can",
    "neu co",
    "chua ro",
    "khong ro",
    "khong biet",
    "tam thoi",
    "sau cung cap"
]

private nonisolated let voiceSOSLocationKeywords = [
    "so nha",
    "duong",
    "hem",
    "ngo",
    "thon",
    "ap",
    "xa",
    "phuong",
    "quan",
    "huyen",
    "thanh pho",
    "tinh",
    "gan",
    "doi dien",
    "ben canh",
    "nga tu",
    "cau",
    "benh vien",
    "truong",
    "cho",
    "nha",
    "tai ",
    "o "
]

private nonisolated let voiceSOSMedicalKeywords = [
    "bi thuong",
    "thuong o",
    "gay",
    "chay mau",
    "bat tinh",
    "kho tho",
    "dau nguc",
    "dot quy",
    "khong the di chuyen",
    "khong di duoc",
    "bong",
    "duoi nuoc",
    "sot",
    "mat nuoc",
    "dau"
]

private nonisolated let voiceSOSCanMoveKeywords = [
    "co the di chuyen",
    "tu di duoc",
    "van di duoc",
    "di lai duoc"
]

private nonisolated let voiceSOSCannotMoveKeywords = [
    "khong the di chuyen",
    "khong di duoc",
    "khong cu dong duoc",
    "liet"
]

private nonisolated let voiceSOSOthersStableKeywords = [
    "nhung nguoi con lai on",
    "nhung nguoi khac on",
    "con lai on",
    "deu on",
    "van on"
]

private nonisolated let voiceSOSOthersUnstableKeywords = [
    "nhung nguoi khac cung bi",
    "con lai cung bi",
    "nhieu nguoi bi thuong",
    "nhung nguoi con lai khong on"
]

private nonisolated let voiceSOSReliefKeywords = [
    "nuoc",
    "thuc pham",
    "do an",
    "luong thuc",
    "thuoc",
    "bang gac",
    "chan",
    "men",
    "giu am",
    "quan ao"
]

private nonisolated func voiceSOSSearchable(_ rawValue: String?) -> String {
    rawValue?
        .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
        .lowercased()
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
        .replacingOccurrences(of: "  ", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        ?? ""
}

private nonisolated func voiceSOSSanitizedText(_ rawValue: String?) -> String? {
    guard let trimmed = rawValue.voiceSOSTrimmedNil else { return nil }
    let key = voiceSOSSearchable(trimmed)
    guard !key.isEmpty else { return nil }
    guard voiceSOSPlaceholderKeywords.contains(where: { key == $0 || key.contains($0) }) == false else {
        return nil
    }
    return trimmed
}

private nonisolated func voiceSOSLooksLikeAddress(_ value: String) -> Bool {
    let key = voiceSOSSearchable(value)
    if key.contains(where: \.isNumber) {
        return true
    }
    return voiceSOSLocationKeywords.contains(where: key.contains)
}

private nonisolated func voiceSOSUniqueStrings(_ values: [String?]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []

    for value in values {
        guard let trimmed = value.voiceSOSTrimmedNil else { continue }
        let key = voiceSOSSearchable(trimmed)
        guard !key.isEmpty, seen.insert(key).inserted else { continue }
        result.append(trimmed)
    }

    return result
}

private nonisolated func voiceSOSUniqueStrings(_ values: [String]) -> [String] {
    voiceSOSUniqueStrings(values.map(Optional.some))
}

private nonisolated func voiceSOSClauses(in text: String) -> [String] {
    text
        .replacingOccurrences(of: "\n", with: " ")
        .split(whereSeparator: { ".;,|!?".contains($0) })
        .compactMap { String($0).voiceSOSTrimmedNil }
}

private nonisolated func voiceSOSNormalizedMedicalIssue(from rawValue: String) -> String? {
    let key = normalizedKey(rawValue)
    if let issue = MedicalIssue(rawValue: key) {
        return issue.rawValue
    }

    let searchable = voiceSOSSearchable(rawValue)
    switch true {
    case searchable.contains("chay mau nhieu"), searchable.contains("mat mau nhieu"):
        return MedicalIssue.severelyBleeding.rawValue
    case searchable.contains("chay mau"):
        return MedicalIssue.bleeding.rawValue
    case searchable.contains("gay"):
        return MedicalIssue.fracture.rawValue
    case searchable.contains("dau dau"), searchable.contains("chan thuong dau"):
        return MedicalIssue.headInjury.rawValue
    case searchable.contains("bong"):
        return MedicalIssue.burns.rawValue
    case searchable.contains("bat tinh"), searchable.contains("ngat"):
        return MedicalIssue.unconscious.rawValue
    case searchable.contains("kho tho"):
        return MedicalIssue.breathingDifficulty.rawValue
    case searchable.contains("dau nguc"), searchable.contains("dot quy"):
        return MedicalIssue.chestPainStroke.rawValue
    case searchable.contains("khong the di chuyen"), searchable.contains("khong di duoc"):
        return MedicalIssue.cannotMove.rawValue
    case searchable.contains("duoi nuoc"):
        return MedicalIssue.drowning.rawValue
    case searchable.contains("sot cao"), searchable.contains("sot"):
        return MedicalIssue.highFever.rawValue
    case searchable.contains("mat nuoc"):
        return MedicalIssue.dehydration.rawValue
    case searchable.contains("benh nen"), searchable.contains("man tinh"):
        return MedicalIssue.chronicDisease.rawValue
    case searchable.contains("luc lan"), searchable.contains("mat phuong huong"):
        return MedicalIssue.confusion.rawValue
    case searchable.contains("thiet bi y te"):
        return MedicalIssue.needsMedicalDevice.rawValue
    case searchable.contains("lac me"), searchable.contains("lac bo me"):
        return MedicalIssue.lostParent.rawValue
    case searchable.contains("sua"), searchable.contains("em be"):
        return MedicalIssue.infantNeedsMilk.rawValue
    default:
        return nil
    }
}

private nonisolated func voiceSOSCondensedMedicalText(_ text: String, victimName: String?) -> String {
    guard let victimName = victimName?.voiceSOSTrimmedNil else { return text }
    guard text.hasPrefix(victimName) else { return text }
    let remainder = text.dropFirst(victimName.count)
        .trimmingCharacters(in: CharacterSet(charactersIn: " :-,"))
    return remainder.voiceSOSTrimmedNil ?? text
}

private nonisolated func voiceSOSKeywords(for situation: RescueSituation) -> [String] {
    switch situation {
    case .trapped:
        return ["mac ket", "bi ket", "tren mai", "khong ra duoc"]
    case .collapsed:
        return ["sap", "nha sap", "sap cong trinh", "sup do"]
    case .dangerZone:
        return ["khu vuc nguy hiem", "nguy hiem", "sat lo", "chay"]
    case .cannotMove:
        return voiceSOSCannotMoveKeywords
    case .flooding:
        return ["ngap", "lu", "nuoc dang", "nuoc len"]
    case .other:
        return []
    }
}

private nonisolated func voiceSOSKeywords(for supply: SupplyNeed) -> [String] {
    switch supply {
    case .water:
        return ["nuoc", "nuoc uong", "khat"]
    case .food:
        return ["thuc pham", "do an", "luong thuc", "gao", "mi", "com", "hamburger"]
    case .clothes:
        return ["quan ao", "ao quan", "do mac", "ao am"]
    case .blanket:
        return ["chan", "men", "giu am", "lanh", "ret"]
    case .medicine:
        return ["thuoc", "y te", "bang gac", "so cuu", "cap cuu"]
    case .other:
        return voiceSOSReliefKeywords
    }
}

private nonisolated func voiceSOSKeywords(for condition: MedicineCondition) -> [String] {
    switch condition {
    case .highFever:
        return ["sot", "sot cao"]
    case .chronicDisease:
        return ["benh nen", "man tinh"]
    case .injured:
        return voiceSOSMedicalKeywords
    case .other:
        return voiceSOSReliefKeywords
    }
}

private nonisolated func voiceSOSKeywords(for need: MedicalSupportNeed) -> [String] {
    switch need {
    case .commonMedicine:
        return ["thuoc", "ha sot", "dau dau", "tieu hoa"]
    case .firstAid:
        return ["so cuu", "bang gac", "oxy gia", "thuoc do"]
    case .chronicMaintenance:
        return ["benh nen", "thuoc duy tri"]
    case .minorInjury:
        return ["bi thuong", "xu ly tai cho"]
    }
}

private nonisolated func voiceSOSKeywords(forMedicalIssue issue: String) -> [String] {
    switch issue {
    case MedicalIssue.severelyBleeding.rawValue:
        return ["chay mau nhieu", "mat mau nhieu"]
    case MedicalIssue.bleeding.rawValue:
        return ["chay mau", "mat mau"]
    case MedicalIssue.fracture.rawValue:
        return ["gay", "gay xuong"]
    case MedicalIssue.headInjury.rawValue:
        return ["dau dau", "chan thuong dau"]
    case MedicalIssue.burns.rawValue:
        return ["bong"]
    case MedicalIssue.unconscious.rawValue:
        return ["bat tinh", "ngat"]
    case MedicalIssue.breathingDifficulty.rawValue:
        return ["kho tho"]
    case MedicalIssue.chestPainStroke.rawValue:
        return ["dau nguc", "dot quy"]
    case MedicalIssue.cannotMove.rawValue:
        return voiceSOSCannotMoveKeywords
    case MedicalIssue.drowning.rawValue:
        return ["duoi nuoc"]
    case MedicalIssue.highFever.rawValue:
        return ["sot", "sot cao"]
    case MedicalIssue.dehydration.rawValue:
        return ["mat nuoc"]
    case MedicalIssue.infantNeedsMilk.rawValue:
        return ["em be", "sua"]
    case MedicalIssue.lostParent.rawValue:
        return ["lac me", "lac bo me"]
    case MedicalIssue.chronicDisease.rawValue:
        return ["benh nen", "man tinh"]
    case MedicalIssue.confusion.rawValue:
        return ["luc lan", "mat phuong huong"]
    case MedicalIssue.needsMedicalDevice.rawValue:
        return ["thiet bi y te"]
    default:
        return []
    }
}

private extension String {
    nonisolated var voiceSOSTrimmedNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    nonisolated var voiceSOSTrimmedNil: String? {
        switch self {
        case .some(let value):
            return value.voiceSOSTrimmedNil
        case .none:
            return nil
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
