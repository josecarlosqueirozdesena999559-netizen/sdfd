import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
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
                heroCard
                summaryRow
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
                Text(appDataViewModel.summary.pendingCount > 0 ? "Painel ativo" : "Tudo organizado")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(appDataViewModel.summary.pendingCount > 0 ? "Voce tem requisicoes aguardando retorno" : "Sua area esta em dia")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(appDataViewModel.summary.pendingCount > 0
                     ? "Acompanhe os pedidos em andamento e avance nas proximas acoes sem perder contexto."
                     : "Use a area de requisicao para registrar uma nova solicitacao quando precisar.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        selectedSection = appDataViewModel.summary.pendingCount > 0 ? .verRequisicoes : .fazerRequisicao
                    } label: {
                        Text(appDataViewModel.summary.pendingCount > 0 ? "Ver requisicoes" : "Nova requisicao")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.deepBlue)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("\(appDataViewModel.requisitions.count) registro(s) carregados")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .padding(24)
        }
        .shadow(color: AppTheme.deepBlue.opacity(0.16), radius: 18, x: 0, y: 10)
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
                .fill(AppTheme.deepBlue)
                .frame(width: 5, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(requisition.materialType)
                    .font(.system(size: 16, weight: .bold))
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
        .padding(16)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
