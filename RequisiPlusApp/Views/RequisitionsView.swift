import SwiftUI

struct RequisitionsView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var searchText = ""
    @State private var selectedFilter: RequestFilter = .all

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            summaryCard
            searchCard
            listCard
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            SmallSummaryCard(
                title: "Total",
                value: "\(appDataViewModel.requisitions.count)",
                icon: "doc.text"
            )

            SmallSummaryCard(
                title: "Pendentes",
                value: "\(pendingCount)",
                icon: "clock"
            )

            SmallSummaryCard(
                title: "Concluidas",
                value: "\(completedCount)",
                icon: "checkmark.circle"
            )
        }
    }

    private var searchCard: some View {
        PrimaryCard {
            SectionHeader(title: "Requisicoes")

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Buscar por numero, categoria ou status", text: $searchText)
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            )

            HStack(spacing: 10) {
                ForEach(RequestFilter.allCases) { filter in
                    filterChip(filter)
                }

                Spacer()
            }
        }
    }

    private var listCard: some View {
        PrimaryCard {
            if filteredRequisitions.isEmpty {
                Text("Nenhuma requisicao encontrada.")
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

    private func filterChip(_ filter: RequestFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .bold))

                Text(filter.title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(selectedFilter == filter ? .white : AppTheme.deepBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedFilter == filter ? AppTheme.deepBlue : AppTheme.primaryBlue.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
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

            HStack(spacing: 14) {
                rowMeta(icon: "calendar", text: requisition.date)
                rowMeta(icon: "building.2", text: requisition.sector)
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
        appDataViewModel.requisitions.filter { requisition in
            let matchesFilter = selectedFilter.matches(requisition: requisition)
            let matchesSearch: Bool

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                matchesSearch = true
            } else {
                let query = searchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                matchesSearch =
                    requisition.materialType.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query) ||
                    requisition.code.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(query) ||
                    requisition.normalizedStatus.contains(query)
            }

            return matchesFilter && matchesSearch
        }
    }

    private var pendingCount: Int {
        appDataViewModel.requisitions.filter { RequestFilter.pending.matches(requisition: $0) }.count
    }

    private var completedCount: Int {
        appDataViewModel.requisitions.filter { RequestFilter.done.matches(requisition: $0) }.count
    }
}

private enum RequestFilter: String, CaseIterable, Identifiable {
    case all
    case pending
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendentes"
        case .done:
            return "Concluidas"
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .pending:
            return "clock.fill"
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
        case .done:
            let status = requisition.normalizedStatus
            return status.contains("conclu") || status.contains("finaliz") || status.contains("entreg")
        }
    }
}

private struct SmallSummaryCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.deepBlue)
                .frame(width: 32, height: 32)
                .background(AppTheme.skyBlue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.panelBorder.opacity(0.95), lineWidth: 1)
        )
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
            return "Concluido"
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
        if statusLabel == "Concluido" {
            return AppTheme.success
        }

        if statusLabel == "Em andamento" || statusLabel == "Assinatura" {
            return AppTheme.warning
        }

        return AppTheme.primaryBlue
    }
}
