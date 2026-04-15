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
                Text("Nenhuma requisiÃ§Ã£o encontrada.")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(statusColor(for: requisition))
                    .frame(width: 6, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(requisition.code)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)

                    Text(requisition.materialType.capitalized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                StatusBadge(status: requisition.statusDisplay)
            }

            HStack(spacing: 10) {
                rowMeta(icon: "calendar", text: requisition.date)
                rowMeta(icon: "building.2", text: requisition.sector)
                rowMeta(icon: "shippingbox", text: requisition.materialType.capitalized)
            }
        }
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.8), lineWidth: 1)
        )
    }

    private func rowMeta(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.9), in: Capsule())
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
            return "ConcluÃ­das"
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
                || status.contains("recebido")
        case .signed:
            return RequestFilter.done.matches(requisition: requisition)
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
            return "ConcluÃ­da"
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
        if statusLabel == "ConcluÃ­da" {
            return AppTheme.success
        }

        if statusLabel == "Em andamento" || statusLabel == "Assinatura" {
            return AppTheme.warning
        }

        return AppTheme.primaryBlue
    }
}
