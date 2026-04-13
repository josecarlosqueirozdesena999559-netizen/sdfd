import SwiftUI

struct RequisitionsView: View {
    var body: some View {
        ScreenContainer(
            title: "Requisicoes",
            subtitle: "Acompanhe solicitacoes em aberto, conferencia e encaminhamento para assinatura."
        ) {
            SectionCard(title: "Fila de Atendimento", systemImage: "list.bullet.rectangle.portrait") {
                VStack(spacing: 14) {
                    ForEach(MockData.requisitions) { requisition in
                        RequisitionRow(requisition: requisition)
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
                InfoBlock(label: "Setor", value: requisition.sector)
                InfoBlock(label: "Solicitante", value: requisition.requestedBy)
                InfoBlock(label: "Data", value: requisition.date)
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
