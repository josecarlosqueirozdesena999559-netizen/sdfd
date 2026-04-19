import Foundation

extension AppDataViewModel {
    var userFacingDashboardAlert: DashboardAlert {
        if hasSignaturePending {
            return DashboardAlert(
                title: "Você tem requisições para assinatura.",
                message: "Abra a aba de requisições para localizar os itens que ainda dependem da sua assinatura.",
                actionTitle: "Ver requisições"
            )
        }

        if hasSignatureAvailable {
            return DashboardAlert(
                title: "Você tem assinaturas disponíveis.",
                message: "O admin já anexou a saída no sistema. Abra suas requisições para conferir e assinar.",
                actionTitle: "Ver requisições"
            )
        }

        if hasCompletedRequisition {
            return DashboardAlert(
                title: "Você concluiu sua requisição.",
                message: "Sua assinatura foi registrada com sucesso. Confira o histórico na aba de requisições.",
                actionTitle: "Ver requisições"
            )
        }

        if hasSubmittedRequisition {
            return DashboardAlert(
                title: "Sua requisição foi enviada.",
                message: "Agora é só acompanhar o andamento até a etapa de assinatura.",
                actionTitle: "Ver requisições"
            )
        }

        return DashboardAlert(
            title: "Sem pendências no momento.",
            message: "Suas requisições estão em dia. Você pode abrir uma nova requisição quando precisar.",
            actionTitle: "Fazer requisição"
        )
    }

    var userFacingNotifications: [NotificationItem] {
        workflowNotifications + notifications.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    var userFacingUnreadNotificationCount: Int {
        userFacingNotifications.filter { $0.isRead == false }.count
    }

    var userFacingNotificationSyncKey: String {
        userFacingNotifications
            .map { "\($0.id):\($0.isRead ? "1" : "0")" }
            .joined(separator: "|")
    }

    private var workflowNotifications: [NotificationItem] {
        if hasSignaturePending {
            return [
                NotificationItem(
                    id: "workflow-signature-pending",
                    title: "Requisições para assinatura",
                    body: "Você tem requisições para assinatura.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        if hasSignatureAvailable {
            return [
                NotificationItem(
                    id: "workflow-signature-ready",
                    title: "Assinaturas disponíveis",
                    body: "Você tem assinaturas disponíveis.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        if hasCompletedRequisition {
            return [
                NotificationItem(
                    id: "workflow-requisition-completed",
                    title: "Requisição concluída",
                    body: "Você concluiu sua requisição.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        if hasSubmittedRequisition {
            return [
                NotificationItem(
                    id: "workflow-requisition-submitted",
                    title: "Requisição enviada",
                    body: "Sua requisição foi enviada.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        return []
    }

    private var hasSignaturePending: Bool {
        requisitions.contains(\.requiresDesktopSignature)
    }

    private var hasSignatureAvailable: Bool {
        requisitions.contains {
            let status = $0.normalizedStatus
            return status.contains("assin") && $0.requiresDesktopSignature == false
        }
    }

    private var hasCompletedRequisition: Bool {
        requisitions.contains {
            let status = $0.normalizedStatus
            return status.contains("conclu") || status.contains("finaliz") || status.contains("entreg")
        }
    }

    private var hasSubmittedRequisition: Bool {
        requisitions.contains {
            let status = $0.normalizedStatus
            return status.contains("aguardando") || status.contains("pendente") || status.contains("recebido")
        }
    }
}
