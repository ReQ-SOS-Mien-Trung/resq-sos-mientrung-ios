import Foundation

enum NotificationOrigin: String, Equatable {
    case backend
    case broadcastPush
}

struct BroadcastAlertLocation: Codable, Equatable {
    let city: String?
    let lat: Double?
    let lon: Double?
}

struct BroadcastActiveAlert: Codable, Equatable {
    let id: String?
    let eventType: String?
    let title: String?
    let severity: String?
    let areasAffected: [String]?
    let startTime: Date?
    let endTime: Date?
    let description: String?
    let instructionChecklist: [String]?
    let source: String?
}

struct BroadcastAlertPayload: Codable, Equatable {
    let location: BroadcastAlertLocation?
    let activeAlerts: [BroadcastActiveAlert]?

    var alerts: [BroadcastActiveAlert] {
        activeAlerts ?? []
    }

    var primaryAlertTitle: String? {
        alerts.compactMap { alert in
            Self.trim(alert.title) ?? Self.normalizedType(alert.eventType)
        }.first
    }

    var summaryMessage: String {
        let city = Self.trim(location?.city)

        switch alerts.count {
        case 0:
            if let city {
                return "Canh bao moi tai \(city)."
            }
            return "Canh bao moi tu he thong."
        case 1:
            let alert = alerts[0]
            var message = Self.trim(alert.title) ?? Self.normalizedType(alert.eventType) ?? "Canh bao moi"

            if let city {
                message += " tai \(city)"
            }

            if let severity = Self.trim(alert.severity) {
                message += " (\(severity.uppercased()))"
            }

            let areas = (alert.areasAffected ?? []).compactMap(Self.trim)
            if areas.isEmpty == false {
                let preview = Array(areas.prefix(2))
                message += ". Khu vuc anh huong: \(preview.joined(separator: ", "))"
                if areas.count > preview.count {
                    message += " va \(areas.count - preview.count) khu vuc khac"
                }
                message += "."
            } else {
                message += "."
            }

            return message
        default:
            var message = "Co \(alerts.count) canh bao dang hoat dong"
            if let city {
                message += " tai \(city)"
            }
            return message + "."
        }
    }

    nonisolated static func decode(fromJSONObject object: Any) -> BroadcastAlertPayload? {
        guard let data = makeJSONData(from: object) else { return nil }
        return try? RealtimeNotification.decoder().decode(BroadcastAlertPayload.self, from: data)
    }

    nonisolated private static func makeJSONData(from object: Any) -> Data? {
        if let rawString = object as? String {
            let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false,
                  trimmed.first == "{" || trimmed.first == "[" else {
                return nil
            }
            return trimmed.data(using: .utf8)
        }

        let normalizedObject = normalizedJSONObject(object)
        guard JSONSerialization.isValidJSONObject(normalizedObject) else {
            return nil
        }

        return try? JSONSerialization.data(withJSONObject: normalizedObject)
    }

    nonisolated private static func normalizedJSONObject(_ object: Any) -> Any {
        if let dictionary = object as? [AnyHashable: Any] {
            return dictionary.reduce(into: [String: Any]()) { partialResult, item in
                guard let key = item.key as? String else { return }
                partialResult[key] = normalizedJSONObject(item.value)
            }
        }

        if let array = object as? [Any] {
            return array.map(normalizedJSONObject)
        }

        return object
    }

    nonisolated private static func trim(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func normalizedType(_ value: String?) -> String? {
        trim(value)?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct RealtimeNotification: Decodable, Identifiable, Equatable {
    let id: String
    let userNotificationId: Int?
    let notificationId: Int?
    let conversationId: Int?
    let title: String?
    let type: String?
    let body: String?
    let alertPayload: BroadcastAlertPayload?
    var isRead: Bool
    let readAt: Date?
    let createdAt: Date?
    let origin: NotificationOrigin

    var displayTitle: String {
        Self.firstNonEmpty(
            title,
            alertPayload?.primaryAlertTitle,
            type?.replacingOccurrences(of: "_", with: " ").capitalized
        ) ?? "Thông báo"
    }

    var displayMessage: String {
        Self.firstNonEmpty(body, alertPayload?.summaryMessage) ?? "Bạn có một thông báo mới từ hệ thống."
    }

    var isPersisted: Bool {
        userNotificationId != nil
    }

    var isChatMessage: Bool {
        type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "chat_message"
    }

    var isBroadcastOnly: Bool {
        origin == .broadcastPush && userNotificationId == nil
    }

    init(
        userNotificationId: Int? = nil,
        notificationId: Int? = nil,
        conversationId: Int? = nil,
        title: String? = nil,
        type: String? = nil,
        body: String? = nil,
        alertPayload: BroadcastAlertPayload? = nil,
        isRead: Bool = false,
        readAt: Date? = nil,
        createdAt: Date? = nil,
        origin: NotificationOrigin = .backend,
        localIdentifier: String? = nil
    ) {
        self.userNotificationId = userNotificationId
        self.notificationId = notificationId
        self.conversationId = conversationId
        self.title = title
        self.type = type
        self.body = body
        self.alertPayload = alertPayload
        self.isRead = isRead
        self.readAt = readAt
        self.createdAt = createdAt
        self.origin = origin
        self.id = localIdentifier ?? Self.makeIdentifier(
            userNotificationId: userNotificationId,
            notificationId: notificationId,
            title: title,
            type: type,
            body: body ?? alertPayload?.summaryMessage,
            createdAt: createdAt,
            origin: origin
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        let userNotificationId = Self.decodeInt(from: container, keys: ["userNotificationId"])
        let notificationId = Self.decodeInt(from: container, keys: ["notificationId"])
        let conversationId = Self.decodeInt(from: container, keys: ["conversationId", "conversation_id"])
        let title = Self.decodeString(from: container, keys: ["title"])
        let type = Self.decodeString(from: container, keys: ["type"])
        let bodyValue = Self.decodeBodyValue(from: container, keys: ["body", "content", "message", "description"])
        let isRead = Self.decodeBool(from: container, keys: ["isRead"]) ?? false
        let readAt = Self.decodeDate(from: container, keys: ["readAt", "read_at"])
        let createdAt = Self.decodeDate(from: container, keys: ["createdAt", "created_at"])

        self.init(
            userNotificationId: userNotificationId,
            notificationId: notificationId,
            conversationId: conversationId,
            title: title,
            type: type,
            body: bodyValue.text,
            alertPayload: bodyValue.payload,
            isRead: isRead,
            readAt: readAt,
            createdAt: createdAt,
            origin: .backend
        )
    }

    nonisolated static func makeBroadcastPush(
        title: String?,
        body: String?,
        type: String?,
        conversationId: Int?,
        messageId: String?,
        alertPayload: BroadcastAlertPayload? = nil,
        createdAt: Date = Date()
    ) -> RealtimeNotification {
        RealtimeNotification(
            conversationId: conversationId,
            title: title,
            type: type,
            body: body,
            alertPayload: alertPayload,
            isRead: false,
            createdAt: createdAt,
            origin: .broadcastPush,
            localIdentifier: messageId.map { "push-\($0)" }
        )
    }

    nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { nestedDecoder in
            let container = try nestedDecoder.singleValueContainer()

            if let rawString = try? container.decode(String.self),
               let date = parseDate(rawString) {
                return date
            }

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
            }

            if let timestamp = try? container.decode(Int.self) {
                let interval = Double(timestamp)
                return Date(timeIntervalSince1970: interval > 10_000_000_000 ? interval / 1000 : interval)
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format for notification payload."
            )
        }
        return decoder
    }

    nonisolated private static func makeIdentifier(
        userNotificationId: Int?,
        notificationId: Int?,
        title: String?,
        type: String?,
        body: String?,
        createdAt: Date?,
        origin: NotificationOrigin
    ) -> String {
        if let userNotificationId {
            return "user-notification-\(userNotificationId)"
        }

        if let notificationId {
            return "notification-\(notificationId)"
        }

        let dateComponent = createdAt.map { String(Int($0.timeIntervalSince1970)) } ?? "no-date"
        let contentComponent = [title, type, body]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "|")

        if !contentComponent.isEmpty {
            return "\(origin.rawValue)-\(dateComponent)-\(contentComponent)"
        }

        return "\(origin.rawValue)-\(UUID().uuidString)"
    }

    nonisolated private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    nonisolated private static func decodeBodyValue(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> (text: String?, payload: BroadcastAlertPayload?) {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let payload = try? container.decode(BroadcastAlertPayload.self, forKey: key) {
                return (nil, payload)
            }

            if let value = try? container.decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { continue }

                if let payload = BroadcastAlertPayload.decode(fromJSONObject: trimmed) {
                    return (nil, payload)
                }

                return (trimmed, nil)
            }

            if let value = try? container.decode(Int.self, forKey: key) {
                return (String(value), nil)
            }
        }

        return (nil, nil)
    }

    nonisolated private static func decodeString(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> String? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)
            if let value = try? container.decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                return trimmed
            }

            if let value = try? container.decode(Int.self, forKey: key) {
                return String(value)
            }
        }

        return nil
    }

    nonisolated private static func decodeInt(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Int? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)
            if let value = try? container.decode(Int.self, forKey: key) {
                return value
            }

            if let rawValue = try? container.decode(String.self, forKey: key),
               let parsed = Int(rawValue) {
                return parsed
            }
        }

        return nil
    }

    nonisolated private static func decodeBool(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Bool? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)
            if let value = try? container.decode(Bool.self, forKey: key) {
                return value
            }

            if let rawValue = try? container.decode(String.self, forKey: key) {
                switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1":
                    return true
                case "false", "0":
                    return false
                default:
                    continue
                }
            }

            if let rawValue = try? container.decode(Int.self, forKey: key) {
                return rawValue != 0
            }
        }

        return nil
    }

    nonisolated private static func decodeDate(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Date? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)
            if let rawValue = try? container.decode(String.self, forKey: key),
               let date = parseDate(rawValue) {
                return date
            }

            if let value = try? container.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
            }

            if let value = try? container.decode(Int.self, forKey: key) {
                let interval = Double(value)
                return Date(timeIntervalSince1970: interval > 10_000_000_000 ? interval / 1000 : interval)
            }
        }

        return nil
    }

    nonisolated private static func parseDate(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let timestamp = Double(trimmed) {
            return Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
        }

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: trimmed) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: trimmed)
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(rawValue: String) {
        self.stringValue = rawValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(rawValue: stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
