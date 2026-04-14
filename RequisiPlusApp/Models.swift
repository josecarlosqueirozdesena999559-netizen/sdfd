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
    let detail: String
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

enum MockData {
    static let materialTypes: [MaterialType] = [
        MaterialType(id: "Material de expediente", title: "Material de expediente", description: "Papel, canetas, pastas e itens de escritorio."),
        MaterialType(id: "Material de limpeza", title: "Material de limpeza", description: "Saneantes, descartaveis e apoio operacional."),
        MaterialType(id: "Insumos de saude", title: "Insumos de saude", description: "Itens hospitalares, consumo clinico e reposicao."),
        MaterialType(id: "TI e perifericos", title: "TI e perifericos", description: "Acessorios, cabos, teclados e apoio tecnico.")
    ]

    static let catalogItems: [MaterialCatalogItem] = [
        MaterialCatalogItem(id: "exp-1", categoryId: "Material de expediente", name: "Papel A4", detail: "Resma branca"),
        MaterialCatalogItem(id: "exp-2", categoryId: "Material de expediente", name: "Caneta azul", detail: "Escritorio"),
        MaterialCatalogItem(id: "exp-3", categoryId: "Material de expediente", name: "Pasta catalogo", detail: "Arquivo"),
        MaterialCatalogItem(id: "limp-1", categoryId: "Material de limpeza", name: "Agua sanitaria", detail: "Limpeza geral"),
        MaterialCatalogItem(id: "limp-2", categoryId: "Material de limpeza", name: "Papel toalha", detail: "Descartavel"),
        MaterialCatalogItem(id: "limp-3", categoryId: "Material de limpeza", name: "Detergente", detail: "Copa e cozinha"),
        MaterialCatalogItem(id: "saude-1", categoryId: "Insumos de saude", name: "Abaixador de lingua", detail: "Hospital"),
        MaterialCatalogItem(id: "saude-2", categoryId: "Insumos de saude", name: "Agua oxigenada", detail: "Hospital"),
        MaterialCatalogItem(id: "saude-3", categoryId: "Insumos de saude", name: "Agulha descartavel", detail: "Hospital"),
        MaterialCatalogItem(id: "ti-1", categoryId: "TI e perifericos", name: "Mouse USB", detail: "Periferico"),
        MaterialCatalogItem(id: "ti-2", categoryId: "TI e perifericos", name: "Teclado USB", detail: "Periferico"),
        MaterialCatalogItem(id: "ti-3", categoryId: "TI e perifericos", name: "Cabo HDMI", detail: "Acessorio")
    ]
}
