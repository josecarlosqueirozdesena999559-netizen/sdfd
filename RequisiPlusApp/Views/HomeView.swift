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
            } else if shouldShowSkeleton {
                skeletonHeroCard
                skeletonRecentRequestsCard
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

                Text(appDataViewModel.userFacingDashboardAlert.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(appDataViewModel.userFacingDashboardAlert.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))

                Button {
                    selectedSection = appDataViewModel.userFacingDashboardAlert.actionTitle == "Fazer requisição" ? .fazerRequisicao : .verRequisicoes
                } label: {
                    Text(appDataViewModel.userFacingDashboardAlert.actionTitle)
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

    private var skeletonHeroCard: some View {
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

                VStack(alignment: .leading, spacing: 10) {
                    placeholderLine(width: 220)
                    placeholderLine(width: 180)
                }

                VStack(alignment: .leading, spacing: 8) {
                    placeholderLine(width: nil, height: 14)
                    placeholderLine(width: 240, height: 14)
                }

                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 144, height: 42)
            }
            .padding(24)
            .redacted(reason: .placeholder)
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

    private var skeletonRecentRequestsCard: some View {
        PrimaryCard {
            SectionHeader(title: "Requisições recentes")

            VStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonRequisitionRow
                }
            }
        }
    }

    private func requisitionRow(_ requisition: Requisition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(statusTint(for: requisition))
                    .frame(width: 5, height: 60)

                VStack(alignment: .leading, spacing: 6) {
                    Text(requisition.materialType.capitalized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)

                    Text("Número \(requisition.codeLabel)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .lineLimit(2)

                    Text(requisition.requestedBy)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                StatusBadge(status: requisition.statusDisplay)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    compactMeta(icon: "calendar", text: requisition.date)
                    compactMeta(icon: "building.2", text: requisition.sector)
                }

                VStack(alignment: .leading, spacing: 8) {
                    compactMeta(icon: "calendar", text: requisition.date)
                    compactMeta(icon: "building.2", text: requisition.sector)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.04), radius: 12, y: 8)
    }

    private var skeletonRequisitionRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppTheme.skyBlue.opacity(0.7))
                    .frame(width: 5, height: 60)

                VStack(alignment: .leading, spacing: 8) {
                    placeholderLine(width: 156, height: 16)
                    placeholderLine(width: 132, height: 13)
                    placeholderLine(width: 118, height: 13)
                }

                Spacer(minLength: 8)

                Capsule()
                    .fill(AppTheme.fieldFill)
                    .frame(width: 92, height: 28)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    skeletonMeta(width: 110)
                    skeletonMeta(width: 126)
                }

                VStack(alignment: .leading, spacing: 8) {
                    skeletonMeta(width: nil)
                    skeletonMeta(width: nil)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.04), radius: 12, y: 8)
        .redacted(reason: .placeholder)
    }

    private func compactMeta(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(2)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.textMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func skeletonMeta(width: CGFloat?) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.fieldFill)
            .frame(maxWidth: width == nil ? .infinity : width, minHeight: 34, maxHeight: 34)
    }

    private func placeholderLine(width: CGFloat?, height: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.88))
            .frame(width: width, height: height)
    }

    private var shouldShowSkeleton: Bool {
        appDataViewModel.isLoading && appDataViewModel.requisitions.isEmpty
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
