import Foundation

struct DashboardAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String
}

struct Requisition: Identifiable {
    let id: String
    let code: String
    let hasRealCode: Bool
    let materialType: String
    let sector: String
    let requestedBy: String
    let status: String
    let date: String
    let requiresDesktopSignature: Bool
    let items: [RequisitionItem]
}

struct RequisitionItem: Identifiable, Hashable {
    let id: String
    let name: String
    let unit: String
    let currentBalance: Double?
    let requestedQuantity: Double?
    let providedQuantity: Double?
    let sortOrder: Int
}

struct MaterialType: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
}

struct MaterialCatalogItem: Identifiable, Hashable {
    let id: String
    let categoryId: String
    let name: String
    let unit: String
    let subcategory: String?

    var detail: String {
        var pieces: [String] = []

        if let subcategory, subcategory.isEmpty == false {
            pieces.append(subcategory.replacingOccurrences(of: "_", with: " "))
        }

        if unit.isEmpty == false {
            pieces.append(unit.replacingOccurrences(of: "_", with: " "))
        }

        return pieces.isEmpty ? "Sem detalhes" : pieces.joined(separator: " | ")
    }
}

struct RequestedItemEntry: Identifiable, Hashable {
    let id: String
    let item: MaterialCatalogItem
    let currentBalance: String
    let requestedQuantity: String

    var trimmedCurrentBalance: String {
        currentBalance.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedRequestedQuantity: String {
        requestedQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAnyValue: Bool {
        trimmedCurrentBalance.isEmpty == false || trimmedRequestedQuantity.isEmpty == false
    }

    var isComplete: Bool {
        trimmedCurrentBalance.isEmpty == false && trimmedRequestedQuantity.isEmpty == false
    }
}

struct UserProfile {
    let id: String
    let authUserId: String?
    let name: String
    let email: String?
    let setor: String
    let cpf: String?
    let role: String
    let funcao: String?
    let categoriasPermitidas: [String]
}

struct NotificationItem: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date?
    let isRead: Bool
    let targetThreadId: String?
    let targetSection: String?
    let isSystemNotification: Bool
}

struct ChatContact: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let setor: String

    var isAdmin: Bool {
        role.normalizedSearchText.contains("admin")
    }
}

struct ChatThread: Identifiable, Hashable {
    let id: String
    let title: String
    let counterpartName: String
    let counterpartRole: String
    let counterpartUserId: String
    let lastMessagePreview: String
    let updatedAt: Date?
    let unreadCount: Int

    var hasUnreadMessages: Bool {
        unreadCount > 0
    }
}

struct ChatAttachment: Hashable {
    let fileName: String
    let fileURL: String
    let mimeType: String
    let storagePath: String?

    var isAudio: Bool {
        mimeType.hasPrefix("audio/")
    }
}

struct ChatMessage: Identifiable, Hashable {
    let id: String
    let threadId: String
    let senderUserId: String
    let senderName: String
    let text: String
    let createdAt: Date?
    let seenAt: Date?
    let deletedAt: Date?
    let attachment: ChatAttachment?

    var isDeleted: Bool {
        deletedAt != nil
    }
}

struct DashboardSummary {
    let pendingCount: Int
    let conferenceCount: Int
    let desktopSignatureCount: Int

    static let empty = DashboardSummary(
        pendingCount: 0,
        conferenceCount: 0,
        desktopSignatureCount: 0
    )
}

extension Requisition {
    var codeLabel: String {
        hasRealCode ? code : "Em processamento"
    }

    var normalizedStatus: String {
        status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var statusDisplay: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var canOpenDetails: Bool {
        hasRealCode && items.isEmpty == false
    }
}

extension MaterialType {
    static func fromCategory(_ category: String) -> MaterialType {
        let formattedTitle = category.formattedCategoryTitle

        return MaterialType(
            id: category,
            title: formattedTitle,
            description: "Categoria liberada."
        )
    }
}

extension String {
    var normalizedSearchText: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedCategoryTitle: String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "limpeza alimenticio", with: "Limpeza e Alimentício", options: [.caseInsensitive])
            .replacingOccurrences(of: "material de ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "insumos de ", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCapitalized
    }
}

extension UserProfile {
    var isAdmin: Bool {
        role.normalizedSearchText.contains("admin")
    }

    var isRegularChatUser: Bool {
        isAdmin == false
    }
}

struct ChatTypingIndicator: Hashable {
    let threadId: String
    let senderUserId: String
    let senderName: String
    let updatedAt: Date
}

extension Date {
    var shortBrazilianDateTime: String {
        AppDateFormatter.shortDateTime.string(from: self)
    }

    var shortBrazilianTime: String {
        AppDateFormatter.shortTime.string(from: self)
    }

    var shortBrazilianDay: String {
        AppDateFormatter.shortDay.string(from: self)
    }
}

enum AppDateFormatter {
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let shortDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd 'de' MMM"
        return formatter
    }()

    static func parse(dateString: String?) -> Date? {
        guard let dateString, dateString.isEmpty == false else {
            return nil
        }

        return iso8601WithFractionalSeconds.date(from: dateString)
            ?? iso8601Basic.date(from: dateString)
    }
}
