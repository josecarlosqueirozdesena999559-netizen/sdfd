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
    let materialType: String
    let sector: String
    let requestedBy: String
    let status: String
    let date: String
    let requiresDesktopSignature: Bool
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
    var normalizedStatus: String {
        status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var statusDisplay: String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

extension MaterialType {
    static func fromCategory(_ category: String) -> MaterialType {
        let formattedTitle = category
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

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
}
