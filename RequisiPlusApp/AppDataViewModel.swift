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
    @Published private(set) var activeTypingIndicator: ChatTypingIndicator?
    @Published var isLoading = false
    @Published var createInProgress = false
    @Published var chatSendInProgress = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userSession: UserSession
    private let databaseService: SupabaseDatabaseService
    private let realtimeService: SupabaseRealtimeService
    private var lastRegisteredPushToken: String?
    private var typingResetTask: Task<Void, Never>?
    private var isSendingTyping = false
    private var typingThreadId: String?

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
        ) { [weak self] event in
            Task {
                await self?.handleRealtimeEvent(event)
            }
        }
    }

    var dashboardAlert: DashboardAlert {
        if summary.desktopSignatureCount > 0 {
            return DashboardAlert(
                title: "Você tem requisições pendentes para assinatura.",
                message: "Abra a aba de requisições para localizar os itens que ainda dependem da sua assinatura.",
                actionTitle: "Ver requisições"
            )
        }

        return DashboardAlert(
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
        inboxNotifications.filter { $0.isRead == false }.count
    }

    var inboxNotifications: [NotificationItem] {
        let remoteNotifications = notifications.sorted {
            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }

        return dashboardNotifications + remoteNotifications
    }

    var notificationSyncKey: String {
        inboxNotifications
            .map { "\($0.id):\($0.isRead ? "1" : "0")" }
            .joined(separator: "|")
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

        guard entries.isEmpty == false else {
            errorMessage = "Adicione pelo menos um item completo antes de enviar a requisição."
            return
        }

        if entries.contains(where: { $0.isComplete == false }) {
            errorMessage = "Preencha saldo atual e quantidade para todos os itens selecionados."
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
        stopTyping()
        activeThreadId = threadId
        activeTypingIndicator = nil
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
            stopTyping()
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
        guard notification.isSystemNotification == false else {
            return
        }

        do {
            try await databaseService.markNotificationAsRead(session: userSession, notificationId: notification.id)
            await refreshSupplementaryData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markVisibleNotificationsAsRead() async {
        let unreadNotifications = notifications.filter { $0.isRead == false }
        guard unreadNotifications.isEmpty == false else {
            return
        }

        do {
            try await databaseService.markNotificationsAsRead(
                session: userSession,
                notificationIds: unreadNotifications.map(\.id)
            )
            await refreshSupplementaryData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTypingState(for thread: ChatThread?, text: String, isRecording: Bool) {
        guard let profile, let thread else {
            stopTyping()
            return
        }

        let hasText = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasText && isRecording == false else {
            stopTyping()
            return
        }

        if isSendingTyping == false || typingThreadId != thread.id {
            realtimeService.sendChatTyping(
                threadId: thread.id,
                senderUserId: profile.id,
                senderName: profile.name,
                isTyping: true
            )
            isSendingTyping = true
            typingThreadId = thread.id
        }

        typingResetTask?.cancel()
        typingResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await self?.stopTyping()
        }
    }

    func stopTyping() {
        typingResetTask?.cancel()
        typingResetTask = nil

        guard let profile, isSendingTyping, let typingThreadId else {
            isSendingTyping = false
            self.typingThreadId = nil
            return
        }

        realtimeService.sendChatTyping(
            threadId: typingThreadId,
            senderUserId: profile.id,
            senderName: profile.name,
            isTyping: false
        )

        isSendingTyping = false
        self.typingThreadId = nil
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

    private func handleRealtimeEvent(_ event: SupabaseRealtimeService.Event) async {
        switch event {
        case .postgresChange(let changedTable):
            await refreshFromRealtime(changedTable: changedTable)
        case .chatTyping(let threadId, let senderUserId, let senderName, let isTyping):
            handleChatTyping(threadId: threadId, senderUserId: senderUserId, senderName: senderName, isTyping: isTyping)
        }
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

    private func handleChatTyping(threadId: String, senderUserId: String, senderName: String, isTyping: Bool) {
        guard profile?.id != senderUserId else { return }
        guard activeThreadId == threadId else { return }

        if isTyping {
            activeTypingIndicator = ChatTypingIndicator(
                threadId: threadId,
                senderUserId: senderUserId,
                senderName: senderName,
                updatedAt: Date()
            )
            scheduleTypingIndicatorTimeout(for: threadId, senderUserId: senderUserId)
        } else if activeTypingIndicator?.senderUserId == senderUserId {
            activeTypingIndicator = nil
        }
    }

    private func scheduleTypingIndicatorTimeout(for threadId: String, senderUserId: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                guard let self else { return }
                guard self.activeTypingIndicator?.threadId == threadId,
                      self.activeTypingIndicator?.senderUserId == senderUserId else { return }
                self.activeTypingIndicator = nil
            }
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

    private var dashboardNotifications: [NotificationItem] {
        if summary.desktopSignatureCount > 0 {
            return [
                NotificationItem(
                    id: "dashboard-signature-pending",
                    title: "Assinaturas pendentes",
                    body: "Você tem requisições pendentes para assinatura.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        if summary.pendingCount > 0 {
            return [
                NotificationItem(
                    id: "dashboard-requisition-pending",
                    title: "Requisições pendentes",
                    body: "Você tem requisições pendentes para acompanhar no app.",
                    createdAt: nil,
                    isRead: false,
                    targetThreadId: nil,
                    targetSection: AppSection.verRequisicoes.rawValue,
                    isSystemNotification: true
                )
            ]
        }

        return []
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
