import SwiftUI

struct RequisitionsView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    private let fixedFilter: RequestFilter?
    @State private var selectedRequisition: Requisition?

    init(fixedFilter: RequestFilter? = nil) {
        self.fixedFilter = fixedFilter
    }

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            listCard
        }
        .sheet(item: $selectedRequisition) { requisition in
            RequisitionDetailsSheet(requisition: requisition)
                .presentationDetents([.large])
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
        Button {
            selectedRequisition = requisition
        } label: {
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
        }
        .buttonStyle(.plain)
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
                || status.contains("recebido")
        case .signed:
            return requisition.normalizedStatus.contains("assin")
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

private struct RequisitionDetailsSheet: View {
    let requisition: Requisition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SoftPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(requisition.code)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.deepBlue)

                            Text(requisition.materialType.capitalized)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            HStack(spacing: 10) {
                                detailPill(icon: "calendar", text: requisition.date)
                                detailPill(icon: "building.2", text: requisition.sector)
                                detailPill(icon: "person.crop.circle", text: requisition.requestedBy)
                            }
                        }
                    }

                    SoftPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "Itens da requisição",
                                subtitle: "\(requisition.items.count) item(ns) encontrado(s)."
                            )

                            requisitionItemsTable
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Detalhes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var requisitionItemsTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                headerCell("Item", width: 44, alignment: .center)
                headerCell("Descrição", alignment: .leading)
                headerCell("Und.", width: 60, alignment: .center)
                headerCell("Saldo Atual", width: 86, alignment: .center)
                headerCell("Qtd. Req.", width: 86, alignment: .center)
                headerCell("Qtd. Forn.", width: 86, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.skyBlue.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if requisition.items.isEmpty {
                HStack(spacing: 8) {
                    valueCell("-", width: 44, alignment: .center, muted: true)
                    valueCell("Nenhum item preenchido", alignment: .leading, muted: true)
                    valueCell("-", width: 60, alignment: .center, muted: true)
                    valueCell("-", width: 86, alignment: .center, muted: true)
                    valueCell("-", width: 86, alignment: .center, muted: true)
                    valueCell("-", width: 86, alignment: .center, muted: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            } else {
                ForEach(Array(requisition.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        valueCell("\(index + 1)", width: 44, alignment: .center)
                        valueCell(item.name, alignment: .leading)
                        valueCell(item.unit, width: 60, alignment: .center)
                        valueCell(item.currentBalance.formattedQuantity, width: 86, alignment: .center)
                        valueCell(item.requestedQuantity.formattedQuantity, width: 86, alignment: .center)
                        valueCell(item.providedQuantity.formattedQuantity, width: 86, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)

                    if item.id != requisition.items.last?.id {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.9), lineWidth: 1)
        )
    }

    private func detailPill(icon: String, text: String) -> some View {
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

    private func headerCell(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
    }

    private func valueCell(_ text: String, width: CGFloat? = nil, alignment: Alignment = .leading, muted: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 13, weight: muted ? .medium : .semibold))
            .foregroundStyle(muted ? AppTheme.textMuted : AppTheme.textPrimary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
    }
}

private extension Optional where Wrapped == Double {
    var formattedQuantity: String {
        guard let value = self else {
            return "-"
        }

        if value.rounded() == value {
            return String(Int(value))
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
