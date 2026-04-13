import Foundation

struct DashboardAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String
}

struct Requisition: Identifiable {
    let id = UUID()
    let code: String
    let sector: String
    let requestedBy: String
    let status: String
    let date: String
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: String
}

enum MockData {
    static let dashboardAlert = DashboardAlert(
        title: "Voce tem requisicoes para atender.",
        message: "Abra a aba de requisicoes para informar as quantidades e encaminhar para assinatura.",
        actionTitle: "Ir para requisicoes"
    )

    static let requisitions: [Requisition] = [
        Requisition(code: "REQ-2041", sector: "Saude", requestedBy: "Maria Jose", status: "Aguardando separacao", date: "13/04/2026"),
        Requisition(code: "REQ-2040", sector: "Educacao", requestedBy: "Joao Carlos", status: "Conferencia", date: "13/04/2026"),
        Requisition(code: "REQ-2038", sector: "Administracao", requestedBy: "Fernanda Lima", status: "Pronto para assinatura", date: "12/04/2026")
    ]

    static let completed: [ActivityItem] = [
        ActivityItem(title: "Saida registrada para Unidade Basica", detail: "Medicamentos e itens de consumo liberados.", date: "Hoje, 15:20"),
        ActivityItem(title: "Requisicao assinada pelo setor de compras", detail: "Processo encaminhado para baixa em estoque.", date: "Hoje, 11:05"),
        ActivityItem(title: "Entrega finalizada para almoxarifado central", detail: "Volumes conferidos e armazenados.", date: "Ontem, 17:40")
    ]
}
