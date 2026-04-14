import SwiftUI

struct ScreenContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if title.isEmpty == false || (subtitle?.isEmpty == false) {
                    VStack(alignment: .leading, spacing: 6) {
                        if title.isEmpty == false {
                            Text(title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        if let subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
}

struct PrimaryCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        padding: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
                .shadow(color: AppTheme.deepBlue.opacity(0.05), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.75), lineWidth: 1)
        )
    }
}

struct CompactMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryBlue)
                .frame(width: 34, height: 34)
                .background(AppTheme.primaryBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.75), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
    }
}
