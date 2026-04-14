import Foundation

@MainActor
final class AppDataViewModel: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var requisitions: [Requisition] = []
    @Published private(set) var summary: DashboardSummary = .empty
    @Published private(set) var materialTypes: [MaterialType] = []
    @Published private(set) var catalogItems: [MaterialCatalogItem] = []
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var adminContacts: [ChatContact] = []
    @Published private(set) var chatThreads: [ChatThread] = []
    @Published private(set) var activeChatMessages: [ChatMessage] = []
    @Published private(set) var activeThreadId: String?
    @Published var isLoading = false
    @Published var createInProgress = false
    @Published var chatSendInProgress = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userSession: UserSession
    private let databaseService: SupabaseDatabaseService
    private let realtimeService: SupabaseRealtimeService
    private var lastRegisteredPushToken: String?

    init(
        userSession: UserSession,
        databaseService: SupabaseDatabaseService = SupabaseDatabaseService(),
        realtimeService: SupabaseRealtimeService = SupabaseRealtimeService()
    ) {
        self.userSession = userSession
        self.databaseService = databaseService
        self.realtimeService = realtimeService

        self.realtimeService.start(
            session: userSession,
            subscriptions: Self.realtimeSubscriptions(for: userSession.user.id)
        ) { [weak self] table in
            Task {
                await self?.refreshFromRealtime(changedTable: table)
            }
        }
    }

    var dashboardAlert: DashboardAlert {
        DashboardAlert(
            title: summary.pendingCount > 0
                ? "Você tem requisições pendentes."
                : "Sem pendências no momento.",
            message: summary.pendingCount > 0
                ? "Abra a aba de requisições para acompanhar o status e conferir os detalhes."
                : "Suas requisições estão em dia. Você pode abrir uma nova requisição quando precisar.",
            actionTitle: summary.pendingCount > 0 ? "Ver requisições" : "Fazer requisição"
        )
    }

    func load() async {
        await performLoad(showLoading: true)
    }

    var unreadNotificationCount: Int {
        notifications.filter { $0.isRead == false }.count
    }

    var canCurrentUserSwitchChatThreads: Bool {
        profile?.isAdmin ?? false
    }

    var currentAdminContact: ChatContact? {
        adminContacts.first(where: { $0.isAdmin }) ?? adminContacts.first
    }

    private func performLoad(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }
        do {
            let profile = try await databaseService.fetchUserProfile(session: userSession)
            async let requisitionsTask = databaseService.fetchRequisitions(session: userSession, profile: profile)
            async let catalogItemsTask = databaseService.fetchCatalogItems(session: userSession, categories: profile.categoriasPermitidas)
            async let notificationsTask = databaseService.fetchNotifications(session: userSession, profile: profile)
            async let adminContactsTask = databaseService.fetchAdminContacts(session: userSession)
            async let chatThreadsTask = databaseService.fetchChatThreads(session: userSession, profile: profile)
            let requisitions = try await requisitionsTask
            let catalogItems = try await catalogItemsTask
            let notifications = try await notificationsTask
            let adminContacts = try await adminContactsTask
            let chatThreads = try await chatThreadsTask

            self.profile = profile
            self.requisitions = requisitions
            self.summary = Self.makeSummary(from: requisitions)
            self.materialTypes = profile.categoriasPermitidas.map(MaterialType.fromCategory)
            self.catalogItems = catalogItems
            self.notifications = notifications
            self.adminContacts = adminContacts
            self.chatThreads = chatThreads
            self.errorMessage = nil

            if let activeThreadId {
                try? await loadMessages(for: activeThreadId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        if showLoading {
            isLoading = false
        }
    }

    func createRequisition(
        materialType: MaterialType?,
        entries: [RequestedItemEntry],
        observation: String
    ) async {
        guard let profile, let materialType else {
            errorMessage = "Não foi possível identificar o usuário ou a categoria para criar a requisição."
            return
        }

        createInProgress = true
        errorMessage = nil
        successMessage = nil

        defer {
            createInProgress = false
        }

        do {
            _ = try await databaseService.createRequisition(
                session: userSession,
                profile: profile,
                materialType: materialType,
                entries: entries,
                observation: observation.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            successMessage = "Requisição enviada com sucesso."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMessages(for threadId: String) async throws {
        activeThreadId = threadId
        activeChatMessages = try await databaseService.fetchChatMessages(session: userSession, threadId: threadId)

        if let profile {
            try? await databaseService.markThreadMessagesAsSeen(session: userSession, profile: profile, threadId: threadId)
            await refreshSupplementaryData()
        }
    }

    func ensureDefaultAdminThread() async {
        guard let profile, profile.isRegularChatUser, chatThreads.isEmpty, let adminContact = currentAdminContact else {
            return
        }

        do {
            let thread = try await databaseService.ensureChatThread(
                session: userSession,
                profile: profile,
                adminContact: adminContact
            )
            chatThreads = [thread]
            try await loadMessages(for: thread.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendChatMessage(
        thread: ChatThread,
        text: String,
        attachmentUpload: ChatAttachmentUpload?
    ) async {
        guard let profile else {
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false || attachmentUpload != nil else {
            return
        }

        chatSendInProgress = true
        defer {
            chatSendInProgress = false
        }

        do {
            _ = try await databaseService.sendChatMessage(
                session: userSession,
                profile: profile,
                thread: thread,
                text: trimmedText,
                attachmentUpload: attachmentUpload
            )

            try await loadMessages(for: thread.id)
            await refreshSupplementaryData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteOwnMessage(_ message: ChatMessage) async {
        do {
            try await databaseService.deleteOwnMessage(session: userSession, messageId: message.id)
            if let activeThreadId {
                try await loadMessages(for: activeThreadId)
            }
            await refreshSupplementaryData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markNotificationAsRead(_ notification: NotificationItem) async {
        do {
            try await databaseService.markNotificationAsRead(session: userSession, notificationId: notification.id)
            await refreshSupplementaryData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func registerPushTokenIfNeeded(deviceToken: String, bundleIdentifier: String, environment: String) async {
        guard let profile, deviceToken.isEmpty == false else {
            return
        }

        let registrationKey = "\(deviceToken)|\(environment)"
        guard lastRegisteredPushToken != registrationKey else {
            return
        }

        do {
            try await databaseService.registerPushToken(
                session: userSession,
                profile: profile,
                deviceToken: deviceToken,
                bundleIdentifier: bundleIdentifier,
                environment: environment
            )
            lastRegisteredPushToken = registrationKey
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeSummary(from requisitions: [Requisition]) -> DashboardSummary {
        DashboardSummary(
            pendingCount: requisitions.filter { $0.normalizedStatus.contains("pendente") }.count,
            conferenceCount: requisitions.filter {
                $0.normalizedStatus.contains("conferencia") || $0.normalizedStatus.contains("separ")
            }.count,
            desktopSignatureCount: requisitions.filter(\.requiresDesktopSignature).count
        )
    }

    private func refreshFromRealtime(changedTable: String?) async {
        guard createInProgress == false else { return }

        switch changedTable {
        case "chat_messages", "chat_threads", "user_notifications":
            await refreshSupplementaryData()
            if let activeThreadId {
                try? await loadMessages(for: activeThreadId)
            }
        default:
            await performLoad(showLoading: false)
        }
    }

    deinit {
        realtimeService.stop()
    }

    private func refreshSupplementaryData() async {
        guard let profile else { return }

        async let notificationsTask = databaseService.fetchNotifications(session: userSession, profile: profile)
        async let threadsTask = databaseService.fetchChatThreads(session: userSession, profile: profile)
        async let contactsTask = databaseService.fetchAdminContacts(session: userSession)

        if let notifications = try? await notificationsTask {
            self.notifications = notifications
        }

        if let chatThreads = try? await threadsTask {
            self.chatThreads = chatThreads
        }

        if let contacts = try? await contactsTask {
            self.adminContacts = contacts
        }
    }

    private static func realtimeSubscriptions(for authUserId: String) -> [SupabaseRealtimeService.Subscription] {
        [
            SupabaseRealtimeService.Subscription(
                topic: "realtime:app-data",
                postgresChanges: [
                    .init(event: "*", schema: "public", table: "itens", filter: nil),
                    .init(event: "*", schema: "public", table: "usuarios", filter: "auth_user_id=eq.\(authUserId)"),
                    .init(event: "*", schema: "public", table: "requisicoes", filter: nil)
                ]
            ),
            SupabaseRealtimeService.Subscription(
                topic: "realtime:chat-data",
                postgresChanges: [
                    .init(event: "*", schema: "public", table: "chat_threads", filter: nil),
                    .init(event: "*", schema: "public", table: "chat_messages", filter: nil),
                    .init(event: "*", schema: "public", table: "user_notifications", filter: nil)
                ]
            )
        ]
    }
}
