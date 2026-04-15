import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                PrimaryCard {
                    SectionHeader(title: "Falha ao carregar")

                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else if appDataViewModel.isLoading && appDataViewModel.requisitions.isEmpty {
                PrimaryCard {
                    SectionHeader(title: "Atualizando")

                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.primaryBlue)

                        Text("Carregando informações do app...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            } else {
                heroCard
                recentRequestsCard
            }
        }
    }

    private var heroCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.heroGradient)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 150, height: 150)
                .offset(x: 28, y: -32)

            VStack(alignment: .leading, spacing: 18) {
                Text("Comunicados")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(appDataViewModel.dashboardAlert.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(appDataViewModel.dashboardAlert.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))

                Button {
                    selectedSection = appDataViewModel.summary.pendingCount > 0 ? .verRequisicoes : .fazerRequisicao
                } label: {
                    Text(appDataViewModel.dashboardAlert.actionTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .shadow(color: AppTheme.deepBlue.opacity(0.16), radius: 18, x: 0, y: 10)
    }

    private var recentRequestsCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Requisições recentes"
            )

            if recentRequisitions.isEmpty {
                Text("Nenhuma requisição encontrada no momento.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                VStack(spacing: 14) {
                    ForEach(recentRequisitions) { requisition in
                        requisitionRow(requisition)
                    }
                }
            }
        }
    }

    private func requisitionRow(_ requisition: Requisition) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(statusTint(for: requisition))
                .frame(width: 5, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(requisition.materialType)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Código \(requisition.code)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text(requisition.date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            StatusBadge(status: requisition.statusDisplay)
        }
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.75), lineWidth: 1)
        )
    }

    private var recentRequisitions: [Requisition] {
        Array(appDataViewModel.requisitions.prefix(3))
    }

    private func statusTint(for requisition: Requisition) -> Color {
        let status = requisition.normalizedStatus
        if status.contains("conclu") || status.contains("finaliz") || status.contains("entreg") {
            return AppTheme.success
        }
        if status.contains("assin") || status.contains("andamento") || status.contains("conferencia") {
            return AppTheme.warning
        }
        return AppTheme.primaryBlue
    }
}
