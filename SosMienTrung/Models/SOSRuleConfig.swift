import Foundation

indirect enum SOSExpressionNode: Codable, Equatable, Hashable {
    case variable(String)
    case number(Double)
    case binary(op: String, left: SOSExpressionNode, right: SOSExpressionNode)
    case unary(op: String, value: SOSExpressionNode)

    private enum CodingKeys: String, CodingKey {
        case op
        case variable = "var"
        case value
        case left
        case right
    }

    init(
        op: String? = nil,
        variable: String? = nil,
        numericValue: Double? = nil,
        left: SOSExpressionNode? = nil,
        right: SOSExpressionNode? = nil,
        operand: SOSExpressionNode? = nil
    ) {
        if let variable {
            self = .variable(variable)
        } else if let numericValue, op == nil {
            self = .number(numericValue)
        } else if let op, let operand {
            self = .unary(op: op, value: operand)
        } else if let op, let left, let right {
            self = .binary(op: op, left: left, right: right)
        } else {
            self = .number(0)
        }
    }

    var op: String? {
        switch self {
        case .binary(let op, _, _), .unary(let op, _):
            return op
        case .variable, .number:
            return nil
        }
    }

    var variable: String? {
        if case .variable(let variable) = self {
            return variable
        }
        return nil
    }

    var numericValue: Double? {
        if case .number(let value) = self {
            return value
        }
        return nil
    }

    var left: SOSExpressionNode? {
        if case .binary(_, let left, _) = self {
            return left
        }
        return nil
    }

    var right: SOSExpressionNode? {
        if case .binary(_, _, let right) = self {
            return right
        }
        return nil
    }

    var operand: SOSExpressionNode? {
        if case .unary(_, let value) = self {
            return value
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let variable = try container.decodeIfPresent(String.self, forKey: .variable) {
            self = .variable(variable)
            return
        }

        if let numericValue = try? container.decode(Double.self, forKey: .value) {
            self = .number(numericValue)
            return
        }

        let op = try container.decodeIfPresent(String.self, forKey: .op)
        let left = try container.decodeIfPresent(SOSExpressionNode.self, forKey: .left)
        let right = try container.decodeIfPresent(SOSExpressionNode.self, forKey: .right)
        let value = try container.decodeIfPresent(SOSExpressionNode.self, forKey: .value)

        if let op, let value {
            self = .unary(op: op, value: value)
        } else if let op, let left, let right {
            self = .binary(op: op, left: left, right: right)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .op,
                in: container,
                debugDescription: "Biểu thức không hợp lệ."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .variable(let variable):
            try container.encode(variable, forKey: .variable)
        case .number(let value):
            try container.encode(value, forKey: .value)
        case .binary(let op, let left, let right):
            try container.encode(op, forKey: .op)
            try container.encode(left, forKey: .left)
            try container.encode(right, forKey: .right)
        case .unary(let op, let value):
            try container.encode(op, forKey: .op)
            try container.encode(value, forKey: .value)
        }
    }
}

struct SOSRulePriorityScoreConfig: Codable, Equatable {
    let formula: String
    let useRequestTypeScore: Bool
    let expression: SOSExpressionNode

    private enum CodingKeys: String, CodingKey {
        case formula
        case useRequestTypeScore = "use_request_type_score"
        case expression
    }

    init(
        formula: String = "ROUND((medical_score + relief_score) * situation_multiplier)",
        useRequestTypeScore: Bool = false,
        expression: SOSExpressionNode = SOSExpressionNode(
            op: "ROUND",
            operand: SOSExpressionNode(
                op: "MUL",
                left: SOSExpressionNode(
                    op: "ADD",
                    left: SOSExpressionNode(variable: "medical_score"),
                    right: SOSExpressionNode(variable: "relief_score")
                ),
                right: SOSExpressionNode(variable: "situation_multiplier")
            )
        )
    ) {
        self.formula = formula
        self.useRequestTypeScore = useRequestTypeScore
        self.expression = expression
    }
}

struct SOSRuleMedicalScoreConfig: Codable, Equatable {
    let formula: String
    let ageWeights: [String: Double]
    let medicalIssueSeverity: [String: Double]

    private enum CodingKeys: String, CodingKey {
        case formula
        case ageWeights = "age_weights"
        case medicalIssueSeverity = "medical_issue_severity"
    }

    init(
        formula: String = "SUM(issue_weight_sum_per_injured_person * age_weight)",
        ageWeights: [String: Double] = [
            "ADULT": 1.0,
            "CHILD": 1.4,
            "ELDERLY": 1.3
        ],
        medicalIssueSeverity: [String: Double] = [
            "UNCONSCIOUS": 5,
            "BREATHING_DIFFICULTY": 5,
            "CHEST_PAIN_STROKE": 5,
            "DROWNING": 5,
            "SEVERELY_BLEEDING": 4,
            "BLEEDING": 4,
            "BURNS": 4,
            "HEAD_INJURY": 4,
            "CANNOT_MOVE": 4,
            "HIGH_FEVER": 3,
            "DEHYDRATION": 3,
            "FRACTURE": 3,
            "INFANT_NEEDS_MILK": 3,
            "LOST_PARENT": 3,
            "CHRONIC_DISEASE": 2,
            "CONFUSION": 2,
            "NEEDS_MEDICAL_DEVICE": 2,
            "OTHER": 1
        ]
    ) {
        self.formula = formula
        self.ageWeights = ageWeights
        self.medicalIssueSeverity = medicalIssueSeverity
    }
}

struct SOSRuleBlanketUrgencyConfig: Codable, Equatable {
    let applyOnlyWhenSupplySelected: Bool
    let applyOnlyWhenAreBlanketsEnoughIsFalse: Bool
    let noneOrNotSelectedScore: Double
    let requestedCountEquals1Score: Double
    let requestedCountMoreThanHalfPeopleScore: Double
    let requestedCountBetween2AndHalfPeopleScore: Double
    let halfPeopleOperator: String

    private enum CodingKeys: String, CodingKey {
        case applyOnlyWhenSupplySelected = "apply_only_when_supply_selected"
        case applyOnlyWhenAreBlanketsEnoughIsFalse = "apply_only_when_are_blankets_enough_is_false"
        case noneOrNotSelectedScore = "none_or_not_selected_score"
        case requestedCountEquals1Score = "requested_count_equals_1_score"
        case requestedCountMoreThanHalfPeopleScore = "requested_count_more_than_half_people_score"
        case requestedCountBetween2AndHalfPeopleScore = "requested_count_between_2_and_half_people_score"
        case halfPeopleOperator = "half_people_operator"
    }

    init(
        applyOnlyWhenSupplySelected: Bool = true,
        applyOnlyWhenAreBlanketsEnoughIsFalse: Bool = true,
        noneOrNotSelectedScore: Double = 0,
        requestedCountEquals1Score: Double = 1,
        requestedCountMoreThanHalfPeopleScore: Double = 3,
        requestedCountBetween2AndHalfPeopleScore: Double = 2,
        halfPeopleOperator: String = ">"
    ) {
        self.applyOnlyWhenSupplySelected = applyOnlyWhenSupplySelected
        self.applyOnlyWhenAreBlanketsEnoughIsFalse = applyOnlyWhenAreBlanketsEnoughIsFalse
        self.noneOrNotSelectedScore = noneOrNotSelectedScore
        self.requestedCountEquals1Score = requestedCountEquals1Score
        self.requestedCountMoreThanHalfPeopleScore = requestedCountMoreThanHalfPeopleScore
        self.requestedCountBetween2AndHalfPeopleScore = requestedCountBetween2AndHalfPeopleScore
        self.halfPeopleOperator = halfPeopleOperator
    }
}

struct SOSRuleClothingUrgencyConfig: Codable, Equatable {
    let applyOnlyWhenSupplySelected: Bool
    let noneOrNotSelectedScore: Double
    let neededPeopleEquals1Score: Double
    let neededPeopleMoreThanHalfPeopleScore: Double
    let neededPeopleBetween2AndHalfPeopleScore: Double
    let halfPeopleOperator: String

    private enum CodingKeys: String, CodingKey {
        case applyOnlyWhenSupplySelected = "apply_only_when_supply_selected"
        case noneOrNotSelectedScore = "none_or_not_selected_score"
        case neededPeopleEquals1Score = "needed_people_equals_1_score"
        case neededPeopleMoreThanHalfPeopleScore = "needed_people_more_than_half_people_score"
        case neededPeopleBetween2AndHalfPeopleScore = "needed_people_between_2_and_half_people_score"
        case halfPeopleOperator = "half_people_operator"
    }

    init(
        applyOnlyWhenSupplySelected: Bool = true,
        noneOrNotSelectedScore: Double = 0,
        neededPeopleEquals1Score: Double = 1,
        neededPeopleMoreThanHalfPeopleScore: Double = 3,
        neededPeopleBetween2AndHalfPeopleScore: Double = 2,
        halfPeopleOperator: String = ">"
    ) {
        self.applyOnlyWhenSupplySelected = applyOnlyWhenSupplySelected
        self.noneOrNotSelectedScore = noneOrNotSelectedScore
        self.neededPeopleEquals1Score = neededPeopleEquals1Score
        self.neededPeopleMoreThanHalfPeopleScore = neededPeopleMoreThanHalfPeopleScore
        self.neededPeopleBetween2AndHalfPeopleScore = neededPeopleBetween2AndHalfPeopleScore
        self.halfPeopleOperator = halfPeopleOperator
    }
}

struct SOSRuleVulnerabilityRawConfig: Codable, Equatable {
    let childPerPerson: Double
    let elderlyPerPerson: Double
    let hasPregnantAny: Double

    private enum CodingKeys: String, CodingKey {
        case childPerPerson = "CHILD_PER_PERSON"
        case elderlyPerPerson = "ELDERLY_PER_PERSON"
        case hasPregnantAny = "HAS_PREGNANT_ANY"
    }

    init(childPerPerson: Double = 1, elderlyPerPerson: Double = 1, hasPregnantAny: Double = 2) {
        self.childPerPerson = childPerPerson
        self.elderlyPerPerson = elderlyPerPerson
        self.hasPregnantAny = hasPregnantAny
    }
}

struct SOSRuleVulnerabilityScoreConfig: Codable, Equatable {
    let formula: String
    let expression: SOSExpressionNode
    let vulnerabilityRaw: SOSRuleVulnerabilityRawConfig
    let capRatio: Double

    private enum CodingKeys: String, CodingKey {
        case formula
        case expression
        case vulnerabilityRaw = "vulnerability_raw"
        case capRatio = "cap_ratio"
    }

    init(
        formula: String = "MIN(vulnerability_raw, supply_urgency_score * cap_ratio)",
        expression: SOSExpressionNode = SOSExpressionNode(
            op: "MIN",
            left: SOSExpressionNode(variable: "vulnerability_raw"),
            right: SOSExpressionNode(
                op: "MUL",
                left: SOSExpressionNode(variable: "supply_urgency_score"),
                right: SOSExpressionNode(variable: "cap_ratio")
            )
        ),
        vulnerabilityRaw: SOSRuleVulnerabilityRawConfig = SOSRuleVulnerabilityRawConfig(),
        capRatio: Double = 0.10
    ) {
        self.formula = formula
        self.expression = expression
        self.vulnerabilityRaw = vulnerabilityRaw
        self.capRatio = capRatio
    }
}

struct SOSRuleSupplyUrgencyConfig: Codable, Equatable {
    let formula: String
    let waterUrgencyScore: [String: Double]
    let foodUrgencyScore: [String: Double]
    let blanketUrgencyScore: SOSRuleBlanketUrgencyConfig
    let clothingUrgencyScore: SOSRuleClothingUrgencyConfig

    private enum CodingKeys: String, CodingKey {
        case formula
        case waterUrgencyScore = "water_urgency_score"
        case foodUrgencyScore = "food_urgency_score"
        case blanketUrgencyScore = "blanket_urgency_score"
        case clothingUrgencyScore = "clothing_urgency_score"
    }

    init(
        formula: String = "water_urgency_score + food_urgency_score + blanket_urgency_score + clothing_urgency_score",
        waterUrgencyScore: [String: Double] = [
            "UNDER_6H": 10,
            "6_TO_12H": 7,
            "12_TO_24H": 4,
            "1_TO_2_DAYS": 2,
            "OVER_2_DAYS": 0,
            "NOT_SELECTED": 0
        ],
        foodUrgencyScore: [String: Double] = [
            "UNDER_12H": 7,
            "12_TO_24H": 5,
            "1_TO_2_DAYS": 3,
            "2_TO_3_DAYS": 1,
            "OVER_3_DAYS": 0,
            "NOT_SELECTED": 0
        ],
        blanketUrgencyScore: SOSRuleBlanketUrgencyConfig = SOSRuleBlanketUrgencyConfig(),
        clothingUrgencyScore: SOSRuleClothingUrgencyConfig = SOSRuleClothingUrgencyConfig()
    ) {
        self.formula = formula
        self.waterUrgencyScore = waterUrgencyScore
        self.foodUrgencyScore = foodUrgencyScore
        self.blanketUrgencyScore = blanketUrgencyScore
        self.clothingUrgencyScore = clothingUrgencyScore
    }
}

struct SOSRuleReliefScoreConfig: Codable, Equatable {
    let formula: String
    let expression: SOSExpressionNode
    let supplyUrgencyScore: SOSRuleSupplyUrgencyConfig
    let vulnerabilityScore: SOSRuleVulnerabilityScoreConfig

    private enum CodingKeys: String, CodingKey {
        case formula
        case expression
        case supplyUrgencyScore = "supply_urgency_score"
        case vulnerabilityScore = "vulnerability_score"
    }

    init(
        formula: String = "supply_urgency_score + vulnerability_score",
        expression: SOSExpressionNode = SOSExpressionNode(
            op: "ADD",
            left: SOSExpressionNode(variable: "supply_urgency_score"),
            right: SOSExpressionNode(variable: "vulnerability_score")
        ),
        supplyUrgencyScore: SOSRuleSupplyUrgencyConfig = SOSRuleSupplyUrgencyConfig(),
        vulnerabilityScore: SOSRuleVulnerabilityScoreConfig = SOSRuleVulnerabilityScoreConfig()
    ) {
        self.formula = formula
        self.expression = expression
        self.supplyUrgencyScore = supplyUrgencyScore
        self.vulnerabilityScore = vulnerabilityScore
    }
}

struct SOSRulePriorityLevelConfig: Codable, Equatable {
    let p1Threshold: Int
    let p2Threshold: Int
    let p3Threshold: Int
    let rule: String

    private enum CodingKeys: String, CodingKey {
        case p1Threshold = "P1_THRESHOLD"
        case p2Threshold = "P2_THRESHOLD"
        case p3Threshold = "P3_THRESHOLD"
        case rule
    }

    init(
        p1Threshold: Int = 70,
        p2Threshold: Int = 45,
        p3Threshold: Int = 25,
        rule: String = "P1/P2 require has_severe_flag, P3 only threshold, else P4"
    ) {
        self.p1Threshold = p1Threshold
        self.p2Threshold = p2Threshold
        self.p3Threshold = p3Threshold
        self.rule = rule
    }
}

struct SOSRuleUIConstraintsConfig: Codable, Equatable {
    let minTotalPeopleToProceed: Int
    let blanketRequestCountDefault: Int
    let blanketRequestCountMin: Int
    let blanketRequestCountMaxFormula: String

    private enum CodingKeys: String, CodingKey {
        case minTotalPeopleToProceed = "MIN_TOTAL_PEOPLE_TO_PROCEED"
        case blanketRequestCountDefault = "BLANKET_REQUEST_COUNT_DEFAULT"
        case blanketRequestCountMin = "BLANKET_REQUEST_COUNT_MIN"
        case blanketRequestCountMaxFormula = "BLANKET_REQUEST_COUNT_MAX_FORMULA"
    }

    init(
        minTotalPeopleToProceed: Int = 1,
        blanketRequestCountDefault: Int = 1,
        blanketRequestCountMin: Int = 1,
        blanketRequestCountMaxFormula: String = "max(1, people_count)"
    ) {
        self.minTotalPeopleToProceed = minTotalPeopleToProceed
        self.blanketRequestCountDefault = blanketRequestCountDefault
        self.blanketRequestCountMin = blanketRequestCountMin
        self.blanketRequestCountMaxFormula = blanketRequestCountMaxFormula
    }
}

struct SOSRuleUIOptionsConfig: Codable, Equatable {
    let waterDuration: [String]
    let foodDuration: [String]

    private enum CodingKeys: String, CodingKey {
        case waterDuration = "WATER_DURATION"
        case foodDuration = "FOOD_DURATION"
    }

    init(
        waterDuration: [String] = [
            "UNDER_6H",
            "6_TO_12H",
            "12_TO_24H",
            "1_TO_2_DAYS",
            "OVER_2_DAYS"
        ],
        foodDuration: [String] = [
            "UNDER_12H",
            "12_TO_24H",
            "1_TO_2_DAYS",
            "2_TO_3_DAYS",
            "OVER_3_DAYS"
        ]
    ) {
        self.waterDuration = waterDuration
        self.foodDuration = foodDuration
    }
}

struct SOSRuleDisplayLabelsConfig: Codable, Equatable {
    let medicalIssues: [String: String]
    let situations: [String: String]
    let waterDuration: [String: String]
    let foodDuration: [String: String]
    let ageGroups: [String: String]
    let requestTypes: [String: String]

    private enum CodingKeys: String, CodingKey {
        case medicalIssues = "medical_issues"
        case situations
        case waterDuration = "water_duration"
        case foodDuration = "food_duration"
        case ageGroups = "age_groups"
        case requestTypes = "request_types"
    }

    init(
        medicalIssues: [String: String] = [
            "UNCONSCIOUS": "Bất tỉnh",
            "BREATHING_DIFFICULTY": "Khó thở",
            "CHEST_PAIN_STROKE": "Đau ngực/đột quỵ",
            "DROWNING": "Đuối nước",
            "SEVERELY_BLEEDING": "Chảy máu nặng",
            "BLEEDING": "Chảy máu",
            "BURNS": "Bỏng",
            "HEAD_INJURY": "Chấn thương đầu",
            "CANNOT_MOVE": "Không thể di chuyển",
            "HIGH_FEVER": "Sốt cao",
            "DEHYDRATION": "Mất nước",
            "FRACTURE": "Gãy xương",
            "INFANT_NEEDS_MILK": "Trẻ sơ sinh cần sữa",
            "LOST_PARENT": "Trẻ lạc người thân",
            "CHRONIC_DISEASE": "Bệnh nền",
            "CONFUSION": "Mất phương hướng",
            "NEEDS_MEDICAL_DEVICE": "Cần thiết bị y tế",
            "OTHER": "Khác",
            "PREGNANCY": "Bầu",
            "COVID": "Covid"
        ],
        situations: [String: String] = [
            "FLOODING": "Ngập lụt",
            "COLLAPSED": "Sập công trình",
            "TRAPPED": "Mắc kẹt",
            "DANGER_ZONE": "Vùng nguy hiểm",
            "CANNOT_MOVE": "Không thể di chuyển",
            "OTHER": "Khác",
            "DEFAULT_WHEN_NULL": "Mặc định"
        ],
        waterDuration: [String: String] = [
            "UNDER_6H": "Dưới 6 giờ",
            "6_TO_12H": "6 đến 12 giờ",
            "12_TO_24H": "12 đến 24 giờ",
            "1_TO_2_DAYS": "1 đến 2 ngày",
            "OVER_2_DAYS": "Trên 2 ngày",
            "NOT_SELECTED": "Chưa chọn"
        ],
        foodDuration: [String: String] = [
            "UNDER_12H": "Dưới 12 giờ",
            "12_TO_24H": "12 đến 24 giờ",
            "1_TO_2_DAYS": "1 đến 2 ngày",
            "2_TO_3_DAYS": "2 đến 3 ngày",
            "OVER_3_DAYS": "Trên 3 ngày",
            "NOT_SELECTED": "Chưa chọn"
        ],
        ageGroups: [String: String] = [
            "ADULT": "Người lớn",
            "CHILD": "Trẻ em",
            "ELDERLY": "Người cao tuổi"
        ],
        requestTypes: [String: String] = [
            "RESCUE": "Cứu nạn",
            "RELIEF": "Tiếp tế",
            "OTHER": "Khác"
        ]
    ) {
        self.medicalIssues = medicalIssues
        self.situations = situations
        self.waterDuration = waterDuration
        self.foodDuration = foodDuration
        self.ageGroups = ageGroups
        self.requestTypes = requestTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SOSRuleDisplayLabelsConfig()
        self.medicalIssues = try container.decodeIfPresent([String: String].self, forKey: .medicalIssues) ?? fallback.medicalIssues
        self.situations = try container.decodeIfPresent([String: String].self, forKey: .situations) ?? fallback.situations
        self.waterDuration = try container.decodeIfPresent([String: String].self, forKey: .waterDuration) ?? fallback.waterDuration
        self.foodDuration = try container.decodeIfPresent([String: String].self, forKey: .foodDuration) ?? fallback.foodDuration
        self.ageGroups = try container.decodeIfPresent([String: String].self, forKey: .ageGroups) ?? fallback.ageGroups
        self.requestTypes = try container.decodeIfPresent([String: String].self, forKey: .requestTypes) ?? fallback.requestTypes
    }
}

struct SOSRuleConfig: Codable, Equatable {
    let id: Int?
    let status: String?
    let createdAt: String?
    let createdBy: String?
    let activatedAt: String?
    let activatedBy: String?
    let updatedAt: String?
    let configVersion: String
    let isActive: Bool
    let medicalSevereIssues: [String]
    let requestTypeScores: [String: Double]
    let priorityScore: SOSRulePriorityScoreConfig
    let medicalScore: SOSRuleMedicalScoreConfig
    let reliefScore: SOSRuleReliefScoreConfig
    let situationMultiplier: [String: Double]
    let priorityLevel: SOSRulePriorityLevelConfig
    let uiConstraints: SOSRuleUIConstraintsConfig
    let uiOptions: SOSRuleUIOptionsConfig
    let displayLabels: SOSRuleDisplayLabelsConfig

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case createdAt = "created_at"
        case createdBy = "created_by"
        case activatedAt = "activated_at"
        case activatedBy = "activated_by"
        case updatedAt = "updated_at"
        case configVersion = "config_version"
        case isActive = "is_active"
        case medicalSevereIssues = "medical_severe_issues"
        case requestTypeScores = "request_type_scores"
        case priorityScore = "priority_score"
        case medicalScore = "medical_score"
        case reliefScore = "relief_score"
        case situationMultiplier = "situation_multiplier"
        case priorityLevel = "priority_level"
        case uiConstraints = "ui_constraints"
        case uiOptions = "ui_options"
        case displayLabels = "display_labels"
    }

    init(
        id: Int? = nil,
        status: String? = nil,
        createdAt: String? = nil,
        createdBy: String? = nil,
        activatedAt: String? = nil,
        activatedBy: String? = nil,
        updatedAt: String? = nil,
        configVersion: String = "SOS_PRIORITY_V2",
        isActive: Bool = true,
        medicalSevereIssues: [String] = [
            "UNCONSCIOUS",
            "BREATHING_DIFFICULTY",
            "CHEST_PAIN_STROKE",
            "DROWNING",
            "SEVERELY_BLEEDING"
        ],
        requestTypeScores: [String: Double] = [
            "RESCUE": 30,
            "RELIEF": 20,
            "OTHER": 10
        ],
        priorityScore: SOSRulePriorityScoreConfig = SOSRulePriorityScoreConfig(),
        medicalScore: SOSRuleMedicalScoreConfig = SOSRuleMedicalScoreConfig(),
        reliefScore: SOSRuleReliefScoreConfig = SOSRuleReliefScoreConfig(),
        situationMultiplier: [String: Double] = [
            "FLOODING": 1.5,
            "COLLAPSED": 1.5,
            "TRAPPED": 1.3,
            "DANGER_ZONE": 1.3,
            "CANNOT_MOVE": 1.2,
            "OTHER": 1.0,
            "DEFAULT_WHEN_NULL": 1.0
        ],
        priorityLevel: SOSRulePriorityLevelConfig = SOSRulePriorityLevelConfig(),
        uiConstraints: SOSRuleUIConstraintsConfig = SOSRuleUIConstraintsConfig(),
        uiOptions: SOSRuleUIOptionsConfig = SOSRuleUIOptionsConfig(),
        displayLabels: SOSRuleDisplayLabelsConfig = SOSRuleDisplayLabelsConfig()
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.activatedAt = activatedAt
        self.activatedBy = activatedBy
        self.updatedAt = updatedAt
        self.configVersion = configVersion
        self.isActive = isActive
        self.medicalSevereIssues = medicalSevereIssues
        self.requestTypeScores = requestTypeScores
        self.priorityScore = priorityScore
        self.medicalScore = medicalScore
        self.reliefScore = reliefScore
        self.situationMultiplier = situationMultiplier
        self.priorityLevel = priorityLevel
        self.uiConstraints = uiConstraints
        self.uiOptions = uiOptions
        self.displayLabels = displayLabels
    }

    static let fallback = SOSRuleConfig()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = SOSRuleConfig.fallback

        self.id = try container.decodeIfPresent(Int.self, forKey: .id)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        self.activatedAt = try container.decodeIfPresent(String.self, forKey: .activatedAt)
        self.activatedBy = try container.decodeIfPresent(String.self, forKey: .activatedBy)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        self.configVersion = try container.decodeIfPresent(String.self, forKey: .configVersion) ?? fallback.configVersion
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? fallback.isActive
        self.medicalSevereIssues = try container.decodeIfPresent([String].self, forKey: .medicalSevereIssues) ?? fallback.medicalSevereIssues
        self.requestTypeScores = try container.decodeIfPresent([String: Double].self, forKey: .requestTypeScores) ?? fallback.requestTypeScores
        self.priorityScore = try container.decodeIfPresent(SOSRulePriorityScoreConfig.self, forKey: .priorityScore) ?? fallback.priorityScore
        self.medicalScore = try container.decodeIfPresent(SOSRuleMedicalScoreConfig.self, forKey: .medicalScore) ?? fallback.medicalScore
        self.reliefScore = try container.decodeIfPresent(SOSRuleReliefScoreConfig.self, forKey: .reliefScore) ?? fallback.reliefScore
        self.situationMultiplier = try container.decodeIfPresent([String: Double].self, forKey: .situationMultiplier) ?? fallback.situationMultiplier
        self.priorityLevel = try container.decodeIfPresent(SOSRulePriorityLevelConfig.self, forKey: .priorityLevel) ?? fallback.priorityLevel
        self.uiConstraints = try container.decodeIfPresent(SOSRuleUIConstraintsConfig.self, forKey: .uiConstraints) ?? fallback.uiConstraints
        self.uiOptions = try container.decodeIfPresent(SOSRuleUIOptionsConfig.self, forKey: .uiOptions) ?? fallback.uiOptions
        self.displayLabels = try container.decodeIfPresent(SOSRuleDisplayLabelsConfig.self, forKey: .displayLabels) ?? fallback.displayLabels
    }
}

enum SOSRuleConfigError: Error, LocalizedError {
    case missingVariable(String)
    case invalidExpression(String)
    case divideByZero

    var errorDescription: String? {
        switch self {
        case .missingVariable(let variable):
            return L10n.SOSRuleConfig.missingVariable(variable)
        case .invalidExpression(let message):
            return message
        case .divideByZero:
            return L10n.SOSRuleConfig.divideByZero
        }
    }
}

enum SOSExpressionEngine {
    static func evaluate(_ node: SOSExpressionNode, context: [String: Double]) throws -> Double {
        if let variable = node.variable?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           variable.isEmpty == false {
            let normalized = SOSRuleConfig.normalizeKey(variable)
            if let value = context[normalized] ?? context[variable] {
                return value
            }
            throw SOSRuleConfigError.missingVariable(variable)
        }

        if let numericValue = node.numericValue, node.op == nil {
            return numericValue
        }

        let operation = SOSRuleConfig.normalizeKey(node.op)
        switch operation {
        case "ADD":
            return try evaluateBinary(node, context: context, +)
        case "SUB":
            return try evaluateBinary(node, context: context, -)
        case "MUL":
            return try evaluateBinary(node, context: context, *)
        case "DIV":
            let numerator = try evaluateRequired(node.left, context: context, label: "left")
            let denominator = try evaluateRequired(node.right, context: context, label: "right")
            guard denominator != 0 else { throw SOSRuleConfigError.divideByZero }
            return numerator / denominator
        case "MIN":
            return try min(
                evaluateRequired(node.left, context: context, label: "left"),
                evaluateRequired(node.right, context: context, label: "right")
            )
        case "MAX":
            return try max(
                evaluateRequired(node.left, context: context, label: "left"),
                evaluateRequired(node.right, context: context, label: "right")
            )
        case "ROUND":
            return try evaluateRequired(node.operand, context: context, label: "value").rounded()
        case "CEIL":
            return try ceil(evaluateRequired(node.operand, context: context, label: "value"))
        case "FLOOR":
            return try floor(evaluateRequired(node.operand, context: context, label: "value"))
        default:
            throw SOSRuleConfigError.invalidExpression("Toán tử không được hỗ trợ: \(node.op ?? "<empty>")")
        }
    }

    private static func evaluateBinary(
        _ node: SOSExpressionNode,
        context: [String: Double],
        _ operation: (Double, Double) -> Double
    ) throws -> Double {
        let left = try evaluateRequired(node.left, context: context, label: "left")
        let right = try evaluateRequired(node.right, context: context, label: "right")
        return operation(left, right)
    }

    private static func evaluateRequired(
        _ node: SOSExpressionNode?,
        context: [String: Double],
        label: String
    ) throws -> Double {
        guard let node else {
            throw SOSRuleConfigError.invalidExpression("Thiếu toán hạng \(label).")
        }
        return try evaluate(node, context: context)
    }
}

struct SOSMedicalIssueDescriptor: Identifiable, Hashable {
    let key: String
    let title: String
    let icon: String
    let category: MedicalIssueCategory

    var id: String { key }
}

struct SOSSituationDescriptor: Identifiable, Hashable {
    let key: String
    let title: String
    let icon: String

    var id: String { key }
}

struct SOSSelectionOption: Identifiable, Hashable {
    let key: String
    let title: String

    var id: String { key }
}

extension SOSRuleConfig {
    nonisolated static func normalizeKey(_ raw: String?) -> String {
        raw?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .uppercased()
            ?? ""
    }

    func ageWeight(for personType: Person.PersonType) -> Double {
        let normalizedKey = Self.normalizeKey(personType.rawValue)
        return medicalScore.ageWeights.first(where: { Self.normalizeKey($0.key) == normalizedKey })?.value
            ?? medicalScore.ageWeights.first(where: { Self.normalizeKey($0.key) == "ADULT" })?.value
            ?? 1.0
    }

    func medicalIssueWeight(for issueKey: String) -> Double {
        let normalizedKey = Self.normalizeKey(issueKey)
        return medicalScore.medicalIssueSeverity.first(where: { Self.normalizeKey($0.key) == normalizedKey })?.value
            ?? medicalScore.medicalIssueSeverity.first(where: { Self.normalizeKey($0.key) == "OTHER" })?.value
            ?? 1.0
    }

    func isSevereMedicalIssue(_ issueKey: String) -> Bool {
        let normalizedKey = Self.normalizeKey(issueKey)
        return medicalSevereIssues.contains { Self.normalizeKey($0) == normalizedKey }
    }

    func requestTypeScore(for sosType: String?) -> Double {
        let normalizedKey = Self.normalizeKey(sosType)
        return requestTypeScores.first(where: { Self.normalizeKey($0.key) == normalizedKey })?.value
            ?? requestTypeScores.first(where: { Self.normalizeKey($0.key) == "OTHER" })?.value
            ?? 0
    }

    func resolveSituationMultiplier(for situationKey: String?) -> Double {
        let normalizedKey = Self.normalizeKey(situationKey)
        if let value = situationMultiplier.first(where: { Self.normalizeKey($0.key) == normalizedKey })?.value {
            return value
        }
        if let other = situationMultiplier.first(where: { Self.normalizeKey($0.key) == "OTHER" })?.value {
            return other
        }
        return situationMultiplier.first(where: { Self.normalizeKey($0.key) == "DEFAULT_WHEN_NULL" })?.value ?? 1
    }

    func mappedWaterUrgency(for optionKey: String?) -> Double {
        resolveMappedScore(in: reliefScore.supplyUrgencyScore.waterUrgencyScore, for: optionKey)
    }

    func mappedFoodUrgency(for optionKey: String?) -> Double {
        resolveMappedScore(in: reliefScore.supplyUrgencyScore.foodUrgencyScore, for: optionKey)
    }

    func minimumPeopleToProceed() -> Int {
        max(1, uiConstraints.minTotalPeopleToProceed)
    }

    func blanketRequestDefault() -> Int {
        max(uiConstraints.blanketRequestCountMin, uiConstraints.blanketRequestCountDefault, 1)
    }

    func blanketRequestMax(for peopleCount: Int) -> Int {
        let formula = uiConstraints.blanketRequestCountMaxFormula
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let floorValue = max(1, uiConstraints.blanketRequestCountMin)

        if formula == "people_count" {
            return max(peopleCount, floorValue)
        }

        if formula.hasPrefix("max("), formula.hasSuffix(")") {
            let inner = String(formula.dropFirst(4).dropLast())
            let parts = inner.split(separator: ",").map(String.init)
            let resolved = parts.map { part -> Int in
                if part == "people_count" {
                    return peopleCount
                }
                return Int(part) ?? floorValue
            }
            return max(resolved.max() ?? peopleCount, floorValue)
        }

        return max(peopleCount, floorValue)
    }

    func waterDurationOptions() -> [SOSSelectionOption] {
        uniqueNormalized(uiOptions.waterDuration, fallback: WaterDuration.allCases.map(\.rawValue))
            .map { SOSSelectionOption(key: $0, title: WaterDuration.title(for: $0)) }
    }

    func foodDurationOptions() -> [SOSSelectionOption] {
        uniqueNormalized(uiOptions.foodDuration, fallback: FoodDuration.allCases.map(\.rawValue))
            .map { SOSSelectionOption(key: $0, title: FoodDuration.title(for: $0)) }
    }

    func situationOptions() -> [SOSSituationDescriptor] {
        let configuredKeys = uniqueNormalized(
            situationMultiplier.keys.filter { Self.normalizeKey($0) != "DEFAULT_WHEN_NULL" },
            fallback: RescueSituation.allCases.map(\.rawValue)
        )

        let preferredOrder = ["TRAPPED", "COLLAPSED", "DANGER_ZONE", "CANNOT_MOVE", "FLOODING", "OTHER"]
        var ordered = preferredOrder.filter(configuredKeys.contains)
        ordered.append(contentsOf: configuredKeys.filter { ordered.contains($0) == false }.sorted())

        if ordered.contains("OTHER") == false {
            ordered.append("OTHER")
        }

        return ordered.map {
            SOSSituationDescriptor(
                key: $0,
                title: RescueSituation.title(for: $0),
                icon: RescueSituation.icon(for: $0)
            )
        }
    }

    func medicalIssueGroups(for personType: Person.PersonType) -> [(category: MedicalIssueCategory, issues: [SOSMedicalIssueDescriptor])] {
        let configuredKeys = uniqueNormalized(
            medicalScore.medicalIssueSeverity.keys,
            fallback: MedicalIssue.issuesForPersonType(personType).map(\.rawValue)
        )

        let preferredOrder = MedicalIssue.issuesForPersonType(personType)
            .map(\.rawValue)
            .map(Self.normalizeKey)
            .filter(configuredKeys.contains)

        var orderedKeys = preferredOrder
        orderedKeys.append(contentsOf: configuredKeys.filter { orderedKeys.contains($0) == false }.sorted())

        let descriptors = orderedKeys.map {
            SOSMedicalIssueDescriptor(
                key: $0,
                title: MedicalIssue.title(for: $0),
                icon: MedicalIssue.icon(for: $0),
                category: MedicalIssue.category(for: $0)
            )
        }

        return MedicalIssueCategory.allCases.compactMap { category in
            let matching = descriptors.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    private func resolveMappedScore(in mapping: [String: Double], for optionKey: String?) -> Double {
        let normalizedKey = Self.normalizeKey(optionKey)
        if let value = mapping.first(where: { Self.normalizeKey($0.key) == normalizedKey })?.value {
            return value
        }
        return mapping.first(where: { Self.normalizeKey($0.key) == "NOT_SELECTED" })?.value ?? 0
    }

    private func uniqueNormalized(_ keys: some Sequence<String>, fallback: [String]) -> [String] {
        let normalizedKeys = keys
            .map(Self.normalizeKey)
            .filter { !$0.isEmpty }

        let source = normalizedKeys.isEmpty ? fallback.map(Self.normalizeKey) : normalizedKeys
        var seen = Set<String>()
        return source.filter { seen.insert($0).inserted }
    }
}

extension RescueSituation {
    static func title(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        let config = SOSRuleConfigStore.shared.currentConfig
        return config.displayLabels.situations.first(where: {
            SOSRuleConfig.normalizeKey($0.key) == normalized
        })?.value ?? RescueSituation(rawValue: normalized)?.title ?? normalized.humanizedConfigLabel()
    }

    static func icon(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        return RescueSituation(rawValue: normalized)?.icon ?? "❓"
    }
}

extension WaterDuration {
    static func title(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        let config = SOSRuleConfigStore.shared.currentConfig
        return config.displayLabels.waterDuration.first(where: {
            SOSRuleConfig.normalizeKey($0.key) == normalized
        })?.value ?? WaterDuration(rawValue: normalized)?.title ?? normalized.humanizedConfigLabel()
    }
}

extension FoodDuration {
    static func title(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        let config = SOSRuleConfigStore.shared.currentConfig
        return config.displayLabels.foodDuration.first(where: {
            SOSRuleConfig.normalizeKey($0.key) == normalized
        })?.value ?? FoodDuration(rawValue: normalized)?.title ?? normalized.humanizedConfigLabel()
    }
}

extension MedicalIssue {
    static func title(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        let config = SOSRuleConfigStore.shared.currentConfig
        return config.displayLabels.medicalIssues.first(where: {
            SOSRuleConfig.normalizeKey($0.key) == normalized
        })?.value ?? MedicalIssue(rawValue: normalized)?.title ?? normalized.humanizedConfigLabel()
    }

    static func icon(for key: String) -> String {
        let normalized = SOSRuleConfig.normalizeKey(key)
        return MedicalIssue(rawValue: normalized)?.icon ?? "🏥"
    }

    static func category(for key: String) -> MedicalIssueCategory {
        let normalized = SOSRuleConfig.normalizeKey(key)
        return MedicalIssue(rawValue: normalized)?.category ?? .other
    }
}

private extension String {
    func humanizedConfigLabel() -> String {
        split(separator: "_")
            .map { chunk in
                let lowercased = chunk.lowercased()
                guard let first = lowercased.first else { return "" }
                return first.uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }
}
