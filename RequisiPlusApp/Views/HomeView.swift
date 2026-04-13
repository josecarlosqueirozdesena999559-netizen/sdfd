import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(
            title: "Avisos",
            subtitle: "Tela inicial com os avisos principais das suas requisicoes."
        ) {
            if let errorMessage = appDataViewModel.errorMessage, errorMessage.isEmpty == false {
                SectionCard(title: "Falha ao carregar", systemImage: "exclamationmark.triangle") {
                    Text(errorMessage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else if appDataViewModel.isLoading && appDataViewModel.requisitions.isEmpty {
                SectionCard(title: "Carregando", systemImage: "hourglass") {
                    ProgressView()
                        .tint(AppTheme.deepBlue)
                }
            } else {
                AlertBanner(item: appDataViewModel.dashboardAlert) {
                    selectedSection = appDataViewModel.summary.pendingCount > 0 ? .verRequisicoes : .fazerRequisicao
                }

                SectionCard(title: "O que voce precisa ver agora", systemImage: "bell.badge") {
                    VStack(alignment: .leading, spacing: 14) {
                        quickRow(label: "Requisicoes pendentes", value: "\(appDataViewModel.summary.pendingCount)")
                        quickRow(label: "Aguardando conferencia", value: "\(appDataViewModel.summary.conferenceCount)")
                        quickRow(label: "Assinar no computador", value: "\(appDataViewModel.summary.desktopSignatureCount)")
                    }
                }
            }
        }
    }

    private func quickRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)
        }
    }
}
