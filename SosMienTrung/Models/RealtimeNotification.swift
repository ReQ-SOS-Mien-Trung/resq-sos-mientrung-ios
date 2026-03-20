import Foundation

enum NotificationOrigin: String, Equatable {
    case backend
    case broadcastPush
}

struct RealtimeNotification: Decodable, Identifiable, Equatable {
    let id: String
    let userNotificationId: Int?
    let notificationId: Int?
    let title: String?
    let type: String?
    let body: String?
    var isRead: Bool
    let readAt: Date?
    let createdAt: Date?
    let origin: NotificationOrigin

    var displayTitle: String {
        Self.firstNonEmpty(title, type?.replacingOccurrences(of: "_", with: " ").capitalized) ?? "Thong bao"
    }

    var displayMessage: String {
        Self.firstNonEmpty(body) ?? "Ban co mot thong bao moi tu he thong."
    }

    var isPersisted: Bool {
        userNotificationId != nil
    }

    var isBroadcastOnly: Bool {
        origin == .broadcastPush && userNotificationId == nil
    }

    init(
        userNotificationId: Int? = nil,
        notificationId: Int? = nil,
        title: String? = nil,
        type: String? = nil,
        body: String? = nil,
        isRead: Bool = false,
        readAt: Date? = nil,
        createdAt: Date? = nil,
        origin: NotificationOrigin = .backend,
        localIdentifier: String? = nil
    ) {
        self.userNotificationId = userNotificationId
        self.notificationId = notificationId
        self.title = title
        self.type = type
        self.body = body
        self.isRead = isRead
        self.readAt = readAt
        self.createdAt = createdAt
        self.origin = origin
        self.id = localIdentifier ?? Self.makeIdentifier(
            userNotificationId: userNotificationId,
            notificationId: notificationId,
            title: title,
            type: type,
            body: body,
            createdAt: createdAt,
            origin: origin
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        let userNotificationId = Self.decodeInt(from: container, keys: ["userNotificationId"])
        let notificationId = Self.decodeInt(from: container, keys: ["notificationId"])
        let title = Self.decodeString(from: container, keys: ["title"])
        let type = Self.decodeString(from: container, keys: ["type"])
        let body = Self.decodeString(from: container, keys: ["body", "content", "message", "description"])
        let isRead = Self.decodeBool(from: container, keys: ["isRead"]) ?? false
        let readAt = Self.decodeDate(from: container, keys: ["readAt", "read_at"])
        let createdAt = Self.decodeDate(from: container, keys: ["createdAt", "created_at"])

        self.init(
            userNotificationId: userNotificationId,
            notificationId: notificationId,
            title: title,
            type: type,
            body: body,
            isRead: isRead,
            readAt: readAt,
            createdAt: createdAt,
            origin: .backend
        )
    }

    static func makeBroadcastPush(
        title: String?,
        body: String?,
        type: String?,
        messageId: String?,
        createdAt: Date = Date()
    ) -> RealtimeNotification {
        RealtimeNotification(
            title: title,
            type: type,
            body: body,
            isRead: false,
            createdAt: createdAt,
            origin: .broadcastPush,
            localIdentifier: messageId.map { "push-\($0)" }
        )
    }

    static func decoder() -> JSONDecoder {
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

    private static func makeIdentifier(
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

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func decodeString(
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

    private static func decodeInt(
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

    private static func decodeBool(
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

    private static func decodeDate(
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

    private static func parseDate(_ rawValue: String) -> Date? {
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
