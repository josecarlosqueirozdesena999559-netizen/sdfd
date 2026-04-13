import SwiftUI

struct ScreenContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)

                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.72))
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: AppTheme.deepBlue.opacity(0.10), radius: 24, x: 0, y: 16)
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.primaryBlue)
                .frame(width: 42, height: 42)
                .background(AppTheme.softBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.cardBlue.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
    }
}

struct AlertBanner: View {
    let item: DashboardAlert
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)

                Text(item.message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.deepBlue.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(action: action) {
                Text(item.actionTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.warmAlert)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppTheme.warmAlertBorder.opacity(0.75), lineWidth: 1)
                )
        )
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(AppTheme.primaryBlue)
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)
            }

            content
        }
        .padding(22)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
    }
}
