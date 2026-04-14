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
            VStack(alignment: .leading, spacing: 18) {
                if title.isEmpty == false || (subtitle?.isEmpty == false) {
                    VStack(alignment: .leading, spacing: 6) {
                        if title.isEmpty == false {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        if let subtitle, subtitle.isEmpty == false {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.panelBorder.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.06), radius: 22, x: 0, y: 12)
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
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                .fill(Color.white.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.panelBorder.opacity(0.95), lineWidth: 1)
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct InfoStrip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)
                .frame(width: 36, height: 36)
                .background(AppTheme.skyBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)

                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(14)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.85), lineWidth: 1)
        )
    }
}

struct SearchFieldRow: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textMuted)

            TextField(prompt, text: $text)
                .foregroundStyle(AppTheme.textPrimary)
                .tint(AppTheme.deepBlue)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        )
    }
}

struct SoftPanel<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        padding: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.fieldBorder.opacity(0.9), lineWidth: 1)
        )
    }
}
