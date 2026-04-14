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
                            .font(.system(size: 17, weight: .semibold))

                        Text(section.tabTitle)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selectedSection == section ? AppTheme.deepBlue : Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        Group {
                            if selectedSection == section {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.deepBlue.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: AppTheme.deepBlue.opacity(0.20), radius: 22, x: 0, y: 14)
        )
    }
}
