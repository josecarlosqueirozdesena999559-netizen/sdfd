import SwiftUI

struct SidebarMenu: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @Binding var selectedSection: AppSection
    var showsCloseButton = false
    var onClose: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("requisi+")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Gestao de requisicoes e atendimento")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Spacer()

                if showsCloseButton {
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        selectedSection = section
                        onClose?()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: section.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 18)

                            Text(section.rawValue)
                                .font(.system(size: 17, weight: .semibold))

                            Spacer()
                        }
                        .foregroundStyle(selectedSection == section ? AppTheme.deepBlue : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(
                            Group {
                                if selectedSection == section {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(selectedSection == section ? 0.38 : 0.10), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Resumo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                HStack {
                    StatusPill(title: "\(appDataViewModel.summary.pendingCount) pendentes", tint: .white.opacity(0.20))
                    StatusPill(title: "\(appDataViewModel.summary.desktopSignatureCount) no computador", tint: .white.opacity(0.12))
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppTheme.sidebarGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: AppTheme.deepBlue.opacity(0.18), radius: 24, x: 0, y: 16)
        )
    }
}

private struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint, in: Capsule())
    }
}

struct GlassTabBar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(section.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedSection == section ? AppTheme.deepBlue : AppTheme.deepBlue.opacity(0.65))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selectedSection == section ? Color.white.opacity(0.88) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.60), lineWidth: 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}
