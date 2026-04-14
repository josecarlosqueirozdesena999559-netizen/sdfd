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
        let pieces = [subcategory, unit]
            .compactMap { value in
                guard let value, value.isEmpty == false else { return nil }
                return value
            }

        return pieces.isEmpty ? "Sem detalhe complementar" : pieces.joined(separator: " • ")
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
        MaterialType(
            id: category,
            title: category,
            description: "Categoria liberada para o seu usuario."
        )
    }
}

extension String {
    var normalizedSearchText: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
