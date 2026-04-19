import SwiftUI

struct RequisitionsView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    private let fixedFilter: RequestFilter?

    init(fixedFilter: RequestFilter? = nil) {
        self.fixedFilter = fixedFilter
    }

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            listCard
        }
    }

    private var listCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Lista completa",
                subtitle: "\(filteredRequisitions.count) resultado(s) exibido(s)."
            )

            if filteredRequisitions.isEmpty {
                Text("Nenhuma requisição encontrada.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredRequisitions) { requisition in
                        requisitionRow(requisition)
                    }
                }
            }
        }
    }

    private func requisitionRow(_ requisition: Requisition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(statusColor(for: requisition))
                    .frame(width: 6, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(requisition.codeLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .lineLimit(2)

                    Text(requisition.materialType.capitalized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    Text(requisition.requestedBy)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                StatusBadge(status: requisition.statusDisplay)
            }

            metadataLayout(for: requisition)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.05), radius: 14, y: 8)
    }

    @ViewBuilder
    private func metadataLayout(for requisition: Requisition) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                rowMeta(icon: "calendar", text: requisition.date)
                rowMeta(icon: "building.2", text: requisition.sector)
                rowMeta(icon: "shippingbox", text: requisition.materialType.capitalized)
            }

            VStack(alignment: .leading, spacing: 8) {
                rowMeta(icon: "calendar", text: requisition.date)
                rowMeta(icon: "building.2", text: requisition.sector)
                rowMeta(icon: "shippingbox", text: requisition.materialType.capitalized)
            }
        }
    }

    private func rowMeta(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(2)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusColor(for requisition: Requisition) -> Color {
        let status = requisition.normalizedStatus
        if status.contains("conclu") || status.contains("finaliz") || status.contains("entreg") {
            return AppTheme.success
        }
        if status.contains("assin") {
            return AppTheme.warning
        }
        return AppTheme.primaryBlue
    }

    private var filteredRequisitions: [Requisition] {
        if let fixedFilter {
            return appDataViewModel.requisitions.filter { fixedFilter.matches(requisition: $0) }
        }

        return appDataViewModel.requisitions
    }
}

enum RequestFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case signed
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendentes"
        case .signed:
            return "Assinadas"
        case .done:
            return "Concluídas"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .pending:
            return "clock.fill"
        case .signed:
            return "signature"
        case .done:
            return "checkmark.circle.fill"
        }
    }

    func matches(requisition: Requisition) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            let status = requisition.normalizedStatus
            return status.contains("pendente")
                || status.contains("andamento")
                || status.contains("conferencia")
                || status.contains("assin")
                || status.contains("recebido")
        case .signed:
            let status = requisition.normalizedStatus
            return status.contains("assin")
                || status.contains("separ")
                || status.contains("conferencia")
        case .done:
            let status = requisition.normalizedStatus
            return status.contains("conclu") || status.contains("finaliz") || status.contains("entreg")
        }
    }
}

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(statusLabel)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private var normalized: String {
        status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private var statusLabel: String {
        if normalized.contains("conclu") || normalized.contains("finaliz") || normalized.contains("entreg") {
            return "Concluída"
        }

        if normalized.contains("andamento") || normalized.contains("conferencia") || normalized.contains("separ") {
            return "Em andamento"
        }

        if normalized.contains("assin") {
            return "Assinatura"
        }

        return "Pendente"
    }

    private var tint: Color {
        if statusLabel == "Concluída" {
            return AppTheme.success
        }

        if statusLabel == "Em andamento" || statusLabel == "Assinatura" {
            return AppTheme.warning
        }

        return AppTheme.primaryBlue
    }
}
