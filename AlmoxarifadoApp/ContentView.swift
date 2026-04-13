import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case inicio = "Início"
    case requisicoes = "Requisições"
    case feitos = "Feitos"
    case perfil = "Perfil"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inicio: return "house"
        case .requisicoes: return "tray.full"
        case .feitos: return "checkmark.seal"
        case .perfil: return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var selectedSection: AppSection = .inicio
    @State private var isSidebarVisible = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            if isCompact {
                compactLayout
            } else {
                regularLayout
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 24) {
            SidebarMenu(selectedSection: $selectedSection)
                .frame(width: 280)

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private var compactLayout: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                MobileHeader(isSidebarVisible: $isSidebarVisible, title: selectedSection.rawValue)

                currentScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
            }

            if isSidebarVisible {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSidebarVisible = false
                        }
                    }

                SidebarMenu(selectedSection: $selectedSection, showsCloseButton: true) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSidebarVisible = false
                    }
                }
                .frame(width: 290)
                .padding(.leading, 12)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack {
                Spacer()
                GlassTabBar(selectedSection: $selectedSection)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSidebarVisible)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedSection {
        case .inicio:
            HomeView(selectedSection: $selectedSection)
        case .requisicoes:
            RequisitionsView()
        case .feitos:
            CompletedView()
        case .perfil:
            ProfileView()
        }
    }
}

private struct MobileHeader: View {
    @Binding var isSidebarVisible: Bool
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.deepBlue)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.whiteOverlay, lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Almoxarifado")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
