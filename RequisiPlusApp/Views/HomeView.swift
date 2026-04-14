import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(
            title: "",
            subtitle: "Um painel simples para acompanhar suas requisicoes pessoais."
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
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: appDataViewModel.summary.pendingCount > 0 ? "clock.badge.exclamationmark.fill" : "checkmark.seal.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(appDataViewModel.summary.pendingCount > 0 ? "Voce tem pendencias" : "Sem pendencias")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(appDataViewModel.summary.pendingCount > 0
                         ? "Acompanhe suas solicitacoes em andamento e veja o que precisa de atencao."
                         : "Suas requisicoes estao em dia. Quando precisar, abra uma nova solicitacao em segundos.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                            in: Capsule()
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
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.primaryBlue.opacity(0.10))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "shippingbox")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryBlue)
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
