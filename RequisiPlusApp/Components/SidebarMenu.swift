import SwiftUI

struct GlassTabBar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: .semibold))

                        Text(section.tabTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selectedSection == section ? AppTheme.deepBlue : Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedSection == section ? Color.white : AppTheme.deepBlue.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(selectedSection == section ? 0.0 : 0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}
