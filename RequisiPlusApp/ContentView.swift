import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case inicio = "Inicio"
    case fazerRequisicao = "Fazer requisicao"
    case verRequisicoes = "Ver requisicoes"
    case adminPendentes = "Pendentes"
    case adminAssinadas = "Assinadas"
    case chat = "Chat"
    case perfil = "Perfil"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inicio: return "house.fill"
        case .fazerRequisicao: return "square.and.pencil"
        case .verRequisicoes: return "doc.text.fill"
        case .adminPendentes: return "clock.badge.fill"
        case .adminAssinadas: return "signature"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .perfil: return "person.crop.circle.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var pushNotificationManager: PushNotificationManager

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                SessionLoadingView()
            } else if let session = authViewModel.session {
                DashboardView(session: session)
                    .environmentObject(pushNotificationManager)
            } else {
                LoginView()
            }
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var pushNotificationManager: PushNotificationManager
    @StateObject private var appDataViewModel: AppDataViewModel
    @State private var selectedSection: AppSection = .inicio
    @State private var showingNotifications = false

    init(session: UserSession) {
        _appDataViewModel = StateObject(wrappedValue: AppDataViewModel(userSession: session))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                MobileHeader(
                    title: selectedSection.headerTitle,
                    unreadNotificationCount: appDataViewModel.unreadNotificationCount,
                    onNotificationsTap: {
                        showingNotifications = true
                    },
                    onChatTap: {
                        selectedSection = .chat
                    },
                    showsChatShortcut: availableSections.contains(.chat)
                )

                currentScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
            }

            GlassTabBar(selectedSection: $selectedSection, availableSections: availableSections)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .task {
            if appDataViewModel.profile == nil && appDataViewModel.isLoading == false {
                await appDataViewModel.load()
                await appDataViewModel.ensureDefaultAdminThread()
            }

            await pushNotificationManager.requestAuthorizationIfNeeded()
            await syncPushTokenIfAvailable()
            syncSelectedSectionWithProfile()
        }
        .onChange(of: appDataViewModel.profile?.isAdmin) { _, _ in
            syncSelectedSectionWithProfile()
        }
        .onChange(of: pushNotificationManager.deviceToken) { _, _ in
            Task {
                await syncPushTokenIfAvailable()
            }
        }
        .onChange(of: appDataViewModel.profile?.id) { _, _ in
            Task {
                await syncPushTokenIfAvailable()
            }
        }
        .onChange(of: pushNotificationManager.pendingThreadId) { _, threadId in
            guard let threadId, availableSections.contains(.chat) else {
                return
            }

            selectedSection = .chat
            Task {
                try? await appDataViewModel.loadMessages(for: threadId)
                await MainActor.run {
                    pushNotificationManager.pendingThreadId = nil
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsSheet(
                notifications: appDataViewModel.notifications,
                onOpenThread: { threadId in
                    showingNotifications = false

                    guard availableSections.contains(.chat) else {
                        return
                    }

                    selectedSection = .chat
                    if let threadId {
                        try? await appDataViewModel.loadMessages(for: threadId)
                    }
                },
                onMarkAsRead: { notification in
                    await appDataViewModel.markNotificationAsRead(notification)
                }
            )
            .presentationDetents([.medium, .large])
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
        case .adminPendentes:
            RequisitionsView(fixedFilter: .pending)
        case .adminAssinadas:
            RequisitionsView(fixedFilter: .signed)
        case .chat:
            MessagingView()
        case .perfil:
            ProfileView()
        }
    }

    private var availableSections: [AppSection] {
        if appDataViewModel.profile?.isAdmin == true {
            return [.adminPendentes, .adminAssinadas]
        }

        return [.inicio, .fazerRequisicao, .verRequisicoes, .chat, .perfil]
    }

    private func syncSelectedSectionWithProfile() {
        guard availableSections.contains(selectedSection) == false, let firstSection = availableSections.first else {
            return
        }

        selectedSection = firstSection
    }

    private func syncPushTokenIfAvailable() async {
        guard let deviceToken = pushNotificationManager.deviceToken else {
            return
        }

        await appDataViewModel.registerPushTokenIfNeeded(
            deviceToken: deviceToken,
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
            environment: pushNotificationManager.apnsEnvironment
        )
    }
}

private struct SessionLoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppTheme.deepBlue)
                    .scaleEffect(1.2)

                Text("Validando sua sessao...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.deepBlue)
            }
        }
    }
}

private struct MobileHeader: View {
    let title: String
    let unreadNotificationCount: Int
    let onNotificationsTap: () -> Void
    let onChatTap: () -> Void
    let showsChatShortcut: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("requisi+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 10) {
                headerIconButton(systemImage: "bell.badge.fill", badge: unreadNotificationCount, action: onNotificationsTap)

                if showsChatShortcut {
                    headerIconButton(systemImage: "bubble.left.and.bubble.right.fill", badge: 0, action: onChatTap)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(
            AppTheme.heroGradient
                .ignoresSafeArea(edges: .top)
        )
    }

    private func headerIconButton(systemImage: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.deepBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if badge > 0 {
                    Text("\(min(badge, 9))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.danger, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

extension AppSection {
    var headerTitle: String {
        switch self {
        case .inicio:
            return "Inicio"
        case .fazerRequisicao:
            return "Fazer requisicao"
        case .verRequisicoes:
            return "Requisicoes"
        case .adminPendentes:
            return "Pendentes"
        case .adminAssinadas:
            return "Assinadas"
        case .chat:
            return "Chat"
        case .perfil:
            return "Perfil"
        }
    }

    var tabTitle: String {
        switch self {
        case .inicio:
            return "Inicio"
        case .fazerRequisicao:
            return "Requisicao"
        case .verRequisicoes:
            return "Requisicoes"
        case .adminPendentes:
            return "Pendentes"
        case .adminAssinadas:
            return "Assinadas"
        case .chat:
            return "Chat"
        case .perfil:
            return "Perfil"
        }
    }
}

private struct NotificationsSheet: View {
    let notifications: [NotificationItem]
    let onOpenThread: (String?) async -> Void
    let onMarkAsRead: (NotificationItem) async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if notifications.isEmpty {
                        PrimaryCard {
                            SectionHeader(title: "Sem notificacoes")
                            Text("As novas mensagens e atualizacoes importantes vao aparecer aqui.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    } else {
                        ForEach(notifications) { notification in
                            Button {
                                Task {
                                    await onMarkAsRead(notification)
                                    await onOpenThread(notification.targetThreadId)
                                }
                            } label: {
                                PrimaryCard(padding: 16) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: notification.isRead ? "bell" : "bell.badge.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(notification.isRead ? AppTheme.textMuted : AppTheme.deepBlue)

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(notification.title)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(AppTheme.textPrimary)

                                            Text(notification.body)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(AppTheme.textMuted)

                                            if let createdAt = notification.createdAt {
                                                Text(createdAt.shortBrazilianDateTime)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(AppTheme.primaryBlue)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Notificacoes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
