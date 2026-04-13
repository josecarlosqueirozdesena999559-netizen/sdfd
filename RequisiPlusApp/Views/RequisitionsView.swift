import SwiftUI

struct RequisitionsView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel

    var body: some View {
        ScreenContainer(
            title: "Ver requisicoes",
            subtitle: "Acompanhe o status das solicitacoes e veja o que precisa ser assinado no computador."
        ) {
            SectionCard(title: "Assinatura", systemImage: "desktopcomputer") {
                Text("As requisicoes com assinatura ficam disponiveis para concluir no computador.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            SectionCard(title: "Fila de Atendimento", systemImage: "list.bullet.rectangle.portrait") {
                if appDataViewModel.isLoading && appDataViewModel.requisitions.isEmpty {
                    ProgressView()
                        .tint(AppTheme.deepBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if appDataViewModel.requisitions.isEmpty {
                    Text("Nenhuma requisicao encontrada para o seu usuario.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 14) {
                        ForEach(appDataViewModel.requisitions) { requisition in
                            RequisitionRow(requisition: requisition)
                        }
                    }
                }
            }
        }
    }
}

private struct RequisitionRow: View {
    let requisition: Requisition

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(requisition.code)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)

                Spacer()

                Text(requisition.status)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.softBlue, in: Capsule())
            }

            HStack {
                InfoBlock(label: "Tipo", value: requisition.materialType)
                InfoBlock(label: "Setor", value: requisition.sector)
                InfoBlock(label: "Solicitante", value: requisition.requestedBy)
                InfoBlock(label: "Data", value: requisition.date)
            }

            if requisition.requiresDesktopSignature {
                Text("Assinatura disponivel apenas no computador")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.softBlue, in: Capsule())
            }
        }
        .padding(18)
        .background(AppTheme.cardBlue.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct InfoBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
