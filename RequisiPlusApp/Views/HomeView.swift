import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(
            title: "",
            subtitle: ""
        ) {
            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                PrimaryCard {
                    SectionHeader(title: "Falha ao carregar", subtitle: "Nao foi possivel atualizar seus dados agora.")

                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            } else if appDataViewModel.isLoading && appDataViewModel.requisitions.isEmpty {
                PrimaryCard {
                    SectionHeader(title: "Atualizando painel", subtitle: "Buscando suas requisicoes mais recentes.")

                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(AppTheme.primaryBlue)

                        Text("Carregando informacoes...")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            } else {
                statusCard
                summaryRow
                recentRequestsCard
            }
        }
    }

    private var statusCard: some View {
        PrimaryCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(appDataViewModel.summary.pendingCount > 0 ? "Pendencias" : "Tudo em dia")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text(appDataViewModel.summary.pendingCount > 0 ? "Voce tem requisicoes pendentes" : "Sem pendencias no momento")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(appDataViewModel.summary.pendingCount > 0
                     ? "Acompanhe suas solicitacoes em andamento e resolva o que estiver faltando."
                     : "Suas requisicoes estao organizadas. Abra uma nova quando precisar.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    selectedSection = appDataViewModel.summary.pendingCount > 0 ? .verRequisicoes : .fazerRequisicao
                } label: {
                    Text(appDataViewModel.summary.pendingCount > 0 ? "Ver requisicoes" : "Nova requisicao")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Text(appDataViewModel.summary.pendingCount > 0
                     ? "\(appDataViewModel.summary.pendingCount) item(ns) aguardando retorno."
                     : "Tudo organizado para o seu dia.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)

                Spacer()
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            CompactMetricCard(
                title: "Pendentes",
                value: "\(appDataViewModel.summary.pendingCount)",
                systemImage: "tray.full"
            )

            CompactMetricCard(
                title: "Concluidas",
                value: "\(completedCount)",
                systemImage: "checkmark.circle"
            )
        }
    }

    private var recentRequestsCard: some View {
        PrimaryCard {
            SectionHeader(
                title: "Requisicoes recentes",
                subtitle: "Veja rapidamente as ultimas movimentacoes."
            )

            if recentRequisitions.isEmpty {
                Text("Nenhuma requisicao encontrada no momento.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentRequisitions) { requisition in
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(AppTheme.deepBlue)
                                .frame(width: 4, height: 44)
                                .padding(.trailing, 2)
                                .overlay(
                                    Color.clear
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(requisition.materialType)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text("Numero \(requisition.code)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryBlue)

                                Text(requisition.date)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.textMuted)
                            }

                            Spacer()

                            StatusBadge(status: requisition.statusDisplay)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var completedCount: Int {
        appDataViewModel.requisitions.filter {
            let status = $0.normalizedStatus
            return status.contains("conclu") || status.contains("finaliz") || status.contains("entreg")
        }.count
    }

    private var recentRequisitions: [Requisition] {
        Array(appDataViewModel.requisitions.prefix(3))
    }
}
