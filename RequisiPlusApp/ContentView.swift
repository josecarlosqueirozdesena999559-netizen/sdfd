import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case inicio = "Inicio"
    case fazerRequisicao = "Fazer requisicao"
    case verRequisicoes = "Ver requisicoes"
    case perfil = "Perfil"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inicio: return "house"
        case .fazerRequisicao: return "square.and.pencil"
        case .verRequisicoes: return "clipboard.text"
        case .perfil: return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                SessionLoadingView()
            } else if let session = authViewModel.session {
                DashboardView(session: session)
            } else {
                LoginView()
            }
        }
    }
}

private struct DashboardView: View {
    @StateObject private var appDataViewModel: AppDataViewModel
    @State private var selectedSection: AppSection = .inicio

    init(session: UserSession) {
        _appDataViewModel = StateObject(wrappedValue: AppDataViewModel(userSession: session))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                MobileHeader(title: selectedSection.rawValue)

                currentScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    .padding(.bottom, 116)
            }

            GlassTabBar(selectedSection: $selectedSection)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .task {
            if appDataViewModel.profile == nil && appDataViewModel.isLoading == false {
                await appDataViewModel.load()
            }
        }
        .environmentObject(appDataViewModel)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedSection {
        case .inicio:
            HomeView(selectedSection: $selectedSection)
        case .fazerRequisicao:
            CreateRequisitionView()
        case .verRequisicoes:
            RequisitionsView()
        case .perfil:
            ProfileView()
        }
    }
}

private struct SessionLoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppTheme.deepBlue)
                    .scaleEffect(1.2)

                Text("Validando sessao...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.deepBlue)
            }
        }
    }
}

private struct MobileHeader: View {
    let title: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("requisi+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

extension AppSection {
    var tabTitle: String {
        switch self {
        case .inicio:
            return "Inicio"
        case .fazerRequisicao:
            return "Requisicao"
        case .verRequisicoes:
            return "Historico"
        case .perfil:
            return "Perfil"
        }
    }
}
