import SwiftUI

struct CompletedView: View {
    var body: some View {
        ScreenContainer(
            title: "Feitos",
            subtitle: "Historico recente das saidas, assinaturas e movimentacoes concluidas."
        ) {
            SectionCard(title: "Ultimas acoes", systemImage: "checkmark.circle") {
                VStack(spacing: 14) {
                    ForEach(MockData.completed) { item in
                        CompletedRow(item: item)
                    }
                }
            }
        }
    }
}

private struct CompletedRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(AppTheme.success.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.success)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)

                Text(item.detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(item.date)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryBlue)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBlue.opacity(0.66), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
