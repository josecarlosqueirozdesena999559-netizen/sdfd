import SwiftUI

struct HomeView: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        ScreenContainer(
            title: "Resumo",
            subtitle: "Painel inicial com avisos e acompanhamento rapido do almoxarifado."
        ) {
            AlertBanner(item: MockData.dashboardAlert) {
                selectedSection = .requisicoes
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                MetricCard(title: "Requisicoes pendentes", value: "08", icon: "tray.full.fill")
                MetricCard(title: "Itens separados hoje", value: "126", icon: "shippingbox.fill")
                MetricCard(title: "Assinaturas aguardando", value: "05", icon: "signature")
            }

            SectionCard(title: "Atendimento do Dia", systemImage: "clock.badge.checkmark") {
                VStack(alignment: .leading, spacing: 14) {
                    quickRow(label: "Proxima prioridade", value: "Unidade de Saude Central")
                    quickRow(label: "Responsavel", value: "Jose Carlos")
                    quickRow(label: "Janela de entrega", value: "16:30 - 17:30")
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
