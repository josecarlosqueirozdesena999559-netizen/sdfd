import SwiftUI

struct RequisitionsView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var searchText = ""
    @State private var selectedFilter: RequestFilter = .all

    var body: some View {
        ScreenContainer(
            title: "",
            subtitle: ""
        ) {
            searchCard
            listCard
        }
    }

    private var searchCard: some View {
        PrimaryCard {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textMuted)

                TextField("Buscar por material, codigo ou status", text: $searchText)
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.fieldBorder, lineWidth: 1)
            )

            HStack(spacing: 10) {
                ForEach(RequestFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selectedFilter == filter ? .white : AppTheme.deepBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selectedFilter == filter ? AppTheme.deepBlue : AppTheme.primaryBlue.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
    }

    private var listCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Historico",
                subtitle: filteredRequisitions.isEmpty ? "Nenhuma requisicao encontrada." : "\(filteredRequisitions.count) resultado(s) encontrado(s)."
            )

            if filteredRequisitions.isEmpty {
                Text("Ajuste sua busca ou envie uma nova requisicao para comecar.")
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
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.primaryBlue.opacity(0.10))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(requisition.materialType)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(requisition.code)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    Spacer()

                    StatusBadge(status: requisition.statusDisplay)
                }

                HStack(spacing: 14) {
                    Label(requisition.date, systemImage: "calendar")
                    Label(requisition.sector, systemImage: "shippingbox")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
            }
        }
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.8), lineWidth: 1)
        )
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

    func matches(requisition: Requisition) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            let status = requisition.normalizedStatus
            return status.contains("pendente") || status.contains("andamento") || status.contains("conferencia")
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
            return "Concluido"
        }

        if normalized.contains("andamento") || normalized.contains("conferencia") || normalized.contains("separ") {
            return "Em andamento"
        }

        return "Pendente"
    }

    private var tint: Color {
        if statusLabel == "Concluido" {
            return AppTheme.success
        }

        if statusLabel == "Em andamento" {
            return Color.orange.opacity(0.90)
        }

        return AppTheme.primaryBlue
    }
}
