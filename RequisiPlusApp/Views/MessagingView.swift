import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct MessagingView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var messageText = ""
    @State private var selectedThreadID: String?
    @State private var showingFileImporter = false
    @State private var threadSearchText = ""
    @StateObject private var recorder = ChatAudioRecorder()
    @State private var pendingAttachment: ChatAttachmentUpload?

    var body: some View {
        GeometryReader { geometry in
            ScreenContainer(title: "", subtitle: "") {
                summaryCard

                if canSwitchThreads && geometry.size.width > 900 {
                    HStack(alignment: .top, spacing: 16) {
                        threadInboxCard(compact: false)
                            .frame(width: 320)

                        conversationCard(maxMessageHeight: 560)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    if canSwitchThreads {
                        threadInboxCard(compact: true)
                    }

                    conversationCard(maxMessageHeight: 420)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data, .pdf, .image, .audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let fileURL = urls.first else {
                return
            }

            Task {
                pendingAttachment = try? await ChatAttachmentUpload.fromFile(url: fileURL)
            }
        }
        .task {
            await appDataViewModel.ensureDefaultAdminThread()
            await syncSelectedThreadIfNeeded()
        }
        .onChange(of: appDataViewModel.chatThreads) { _, _ in
            Task {
                await syncSelectedThreadIfNeeded()
            }
        }
        .onChange(of: appDataViewModel.activeThreadId) { _, newValue in
            guard let newValue else { return }
            selectedThreadID = newValue
        }
    }

    private var summaryCard: some View {
        PrimaryCard {
            SectionHeader(
                title: canSwitchThreads ? "Central do almoxarifado" : "Canal com o almoxarifado",
                subtitle: canSwitchThreads
                    ? "Troque entre conversas, acompanhe nao lidas e responda cada setor no mesmo lugar."
                    : "Voce conversa direto com a administracao. As mensagens aparecem em tempo real."
            )

            ViewThatFits {
                HStack(spacing: 12) {
                    summaryMetrics
                }

                VStack(spacing: 12) {
                    summaryMetrics
                }
            }
        }
    }

    @ViewBuilder
    private var summaryMetrics: some View {
        InfoStrip(
            icon: canSwitchThreads ? "tray.full.fill" : "person.2.fill",
            title: canSwitchThreads ? "Atendimentos" : "Canal",
            value: canSwitchThreads ? "\(appDataViewModel.chatThreads.count)" : (selectedThread?.counterpartName ?? "Administracao")
        )

        InfoStrip(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Mensagens",
            value: "\(appDataViewModel.activeChatMessages.count)"
        )

        InfoStrip(
            icon: "bell.badge.fill",
            title: "Nao lidas",
            value: "\(totalUnreadThreadCount)"
        )
    }

    private func threadInboxCard(compact: Bool) -> some View {
        PrimaryCard {
            SectionHeader(
                title: "Conversas",
                subtitle: compact
                    ? "Selecione um atendimento para abrir a conversa."
                    : "Fila de mensagens do almoxarifado."
            )

            SearchFieldRow(prompt: "Buscar por nome, setor ou mensagem", text: $threadSearchText)

            if filteredThreads.isEmpty {
                emptyThreadsState
            } else if compact {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredThreads) { thread in
                            threadPill(thread)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredThreads) { thread in
                        threadRow(thread)
                    }
                }
            }
        }
    }

    private func conversationCard(maxMessageHeight: CGFloat) -> some View {
        PrimaryCard {
            if let selectedThread {
                conversationHeader(for: selectedThread)
                messagesPanel(maxHeight: maxMessageHeight)
                composerCard
            } else {
                emptyConversationState
            }
        }
    }

    private func conversationHeader(for thread: ChatThread) -> some View {
        HStack(alignment: .center, spacing: 14) {
            avatarView(for: thread.counterpartName, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(thread.counterpartName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(thread.counterpartRole)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)

                Text(thread.updatedAt?.shortBrazilianDateTime ?? "Conversa pronta para receber mensagens")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSoft)
            }

            Spacer()

            if thread.hasUnreadMessages {
                unreadBadge(count: thread.unreadCount)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        )
    }

    private func messagesPanel(maxHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    if appDataViewModel.activeChatMessages.isEmpty {
                        emptyMessagesState
                    } else {
                        ForEach(Array(appDataViewModel.activeChatMessages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDayDivider(at: index) {
                                Text(message.createdAt?.shortBrazilianDay ?? "Agora")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.fieldFill, in: Capsule())
                            }

                            messageRow(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 240, maxHeight: maxHeight)
            .onAppear {
                scrollToBottom(with: proxy)
            }
            .onChange(of: appDataViewModel.activeChatMessages.count) { _, _ in
                scrollToBottom(with: proxy)
            }
        }
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let pendingAttachment {
                SoftPanel {
                    HStack(spacing: 12) {
                        Image(systemName: pendingAttachment.mimeType.hasPrefix("audio/") ? "waveform" : "paperclip")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.deepBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anexo pronto para envio")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(pendingAttachment.fileName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Remover") {
                            self.pendingAttachment = nil
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                    }
                }
            }

            TextField("Escreva sua mensagem", text: $messageText, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )

            HStack(spacing: 10) {
                Button {
                    showingFileImporter = true
                } label: {
                    composerActionLabel(systemImage: "paperclip", title: "Arquivo")
                }

                Button {
                    Task {
                        if recorder.isRecording {
                            pendingAttachment = try? await recorder.stopRecording()
                        } else {
                            try? await recorder.startRecording()
                        }
                    }
                } label: {
                    composerActionLabel(
                        systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill",
                        title: recorder.isRecording ? "Parar audio" : "Audio"
                    )
                }

                Spacer()

                Button {
                    guard let selectedThread else {
                        return
                    }

                    Task {
                        await appDataViewModel.sendChatMessage(
                            thread: selectedThread,
                            text: messageText,
                            attachmentUpload: pendingAttachment
                        )
                        messageText = ""
                        pendingAttachment = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        if appDataViewModel.chatSendInProgress {
                            ProgressView()
                                .tint(.white)
                        }

                        Text("Enviar")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppTheme.heroGradient, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedThread == nil || isComposerEmpty)
                .opacity(selectedThread == nil || isComposerEmpty ? 0.65 : 1)
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isMine = message.senderUserId == appDataViewModel.profile?.id

        return HStack(alignment: .bottom, spacing: 10) {
            if isMine {
                Spacer(minLength: 54)
            } else {
                avatarView(for: message.senderName, size: 40)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                Text(isMine ? "Voce" : message.senderName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)

                VStack(alignment: .leading, spacing: 10) {
                    if message.isDeleted {
                        Text("Mensagem apagada")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isMine ? Color.white.opacity(0.84) : AppTheme.textMuted)
                    } else {
                        if message.text.isEmpty == false {
                            Text(message.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isMine ? .white : AppTheme.textPrimary)
                        }

                        if let attachment = message.attachment, let attachmentURL = URL(string: attachment.fileURL) {
                            Link(destination: attachmentURL) {
                                HStack(spacing: 10) {
                                    Image(systemName: attachment.isAudio ? "waveform" : "paperclip")
                                        .font(.system(size: 14, weight: .bold))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.fileName)
                                            .lineLimit(1)
                                        Text(attachment.isAudio ? "Abrir audio" : "Abrir anexo")
                                            .font(.system(size: 11, weight: .semibold))
                                            .opacity(0.82)
                                    }
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isMine ? .white : AppTheme.deepBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(isMine ? Color.white.opacity(0.16) : AppTheme.skyBlue.opacity(0.7))
                                )
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        if let createdAt = message.createdAt {
                            Text(createdAt.shortBrazilianTime)
                        }

                        if isMine {
                            Text(message.seenAt == nil ? "Enviado" : "Visto")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isMine ? Color.white.opacity(0.76) : AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isMine ? AppTheme.deepBlue : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isMine ? AppTheme.deepBlue : AppTheme.fieldBorder, lineWidth: 1)
                )

                if isMine && message.isDeleted == false {
                    Button("Apagar mensagem") {
                        Task {
                            await appDataViewModel.deleteOwnMessage(message)
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.danger)
                }
            }
            .frame(maxWidth: 320, alignment: isMine ? .trailing : .leading)

            if isMine {
                avatarView(for: message.senderName, size: 40)
            } else {
                Spacer(minLength: 54)
            }
        }
    }

    private func threadRow(_ thread: ChatThread) -> some View {
        Button {
            openThread(thread)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selectedThreadID == thread.id ? AppTheme.deepBlue : AppTheme.skyBlue)
                        .frame(width: 46, height: 46)

                    Text(initials(for: thread.counterpartName))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selectedThreadID == thread.id ? .white : AppTheme.deepBlue)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(thread.counterpartName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)

                        if thread.hasUnreadMessages {
                            unreadBadge(count: thread.unreadCount)
                        }
                    }

                    Text(thread.counterpartRole)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)

                    Text(thread.lastMessagePreview)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .lineLimit(2)

                    if let updatedAt = thread.updatedAt {
                        Text(updatedAt.shortBrazilianDateTime)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSoft)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectedThreadID == thread.id ? AppTheme.cardBlue : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selectedThreadID == thread.id ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func threadPill(_ thread: ChatThread) -> some View {
        Button {
            openThread(thread)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(thread.counterpartName)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)

                    if thread.hasUnreadMessages {
                        unreadBadge(count: thread.unreadCount)
                    }
                }

                Text(thread.lastMessagePreview)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(selectedThreadID == thread.id ? .white : AppTheme.textPrimary)
            .frame(width: 240, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectedThreadID == thread.id ? AppTheme.deepBlue : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selectedThreadID == thread.id ? AppTheme.deepBlue : AppTheme.fieldBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyThreadsState: some View {
        SoftPanel {
            Text("Nenhuma conversa encontrada.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Quando um usuario iniciar contato, o atendimento aparece aqui.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    private var emptyConversationState: some View {
        SoftPanel {
            SectionHeader(
                title: canSwitchThreads ? "Selecione uma conversa" : "Preparando o canal",
                subtitle: canSwitchThreads
                    ? "Abra um atendimento da lista para responder."
                    : "Assim que a conversa com a administracao estiver pronta, ela aparece aqui."
            )
        }
    }

    private var emptyMessagesState: some View {
        SoftPanel {
            Text("Ainda nao ha mensagens nesta conversa.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Use o campo abaixo para iniciar o atendimento.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    private func avatarView(for name: String, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.skyBlue)
                .frame(width: size, height: size)

            Text(initials(for: name))
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(AppTheme.deepBlue)
        }
    }

    private func unreadBadge(count: Int) -> some View {
        Text("\(min(count, 99))")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.primaryBlue, in: Capsule())
    }

    private func composerActionLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(AppTheme.deepBlue)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.fieldBorder, lineWidth: 1)
        )
    }

    private func openThread(_ thread: ChatThread) {
        selectedThreadID = thread.id
        Task {
            try? await appDataViewModel.loadMessages(for: thread.id)
        }
    }

    private func syncSelectedThreadIfNeeded() async {
        if let activeThreadId = appDataViewModel.activeThreadId,
           appDataViewModel.chatThreads.contains(where: { $0.id == activeThreadId }) {
            selectedThreadID = activeThreadId
            return
        }

        if let selectedThreadID,
           appDataViewModel.chatThreads.contains(where: { $0.id == selectedThreadID }) {
            return
        }

        guard let nextThread = appDataViewModel.chatThreads.first else {
            selectedThreadID = nil
            return
        }

        selectedThreadID = nextThread.id
        try? await appDataViewModel.loadMessages(for: nextThread.id)
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastMessage = appDataViewModel.activeChatMessages.last else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func shouldShowDayDivider(at index: Int) -> Bool {
        guard let currentDate = appDataViewModel.activeChatMessages[index].createdAt else {
            return index == 0
        }

        guard index > 0, let previousDate = appDataViewModel.activeChatMessages[index - 1].createdAt else {
            return true
        }

        return Calendar.current.isDate(currentDate, inSameDayAs: previousDate) == false
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let joined = parts.compactMap { $0.first }.map(String.init).joined()
        return joined.isEmpty ? "AD" : joined.uppercased()
    }

    private var canSwitchThreads: Bool {
        appDataViewModel.canCurrentUserSwitchChatThreads
    }

    private var selectedThread: ChatThread? {
        appDataViewModel.chatThreads.first { $0.id == selectedThreadID }
    }

    private var filteredThreads: [ChatThread] {
        let search = threadSearchText.normalizedSearchText
        guard search.isEmpty == false else {
            return appDataViewModel.chatThreads
        }

        return appDataViewModel.chatThreads.filter { thread in
            thread.counterpartName.normalizedSearchText.contains(search)
                || thread.counterpartRole.normalizedSearchText.contains(search)
                || thread.lastMessagePreview.normalizedSearchText.contains(search)
        }
    }

    private var totalUnreadThreadCount: Int {
        appDataViewModel.chatThreads.reduce(0) { $0 + $1.unreadCount }
    }

    private var isComposerEmpty: Bool {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachment == nil
    }
}

@MainActor
final class ChatAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false

    private var audioRecorder: AVAudioRecorder?
    private var currentURL: URL?

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        if await requestMicrophonePermission() == false {
            throw NSError(domain: "ChatAudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permissao de microfone negada."])
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        currentURL = url
        isRecording = true
    }

    func stopRecording() async throws -> ChatAttachmentUpload? {
        audioRecorder?.stop()
        isRecording = false

        guard let currentURL else {
            return nil
        }

        let data = try Data(contentsOf: currentURL)
        self.currentURL = nil
        return ChatAttachmentUpload(fileName: "audio.m4a", mimeType: "audio/m4a", data: data)
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private extension ChatAttachmentUpload {
    static func fromFile(url: URL) async throws -> ChatAttachmentUpload {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return ChatAttachmentUpload(fileName: url.lastPathComponent, mimeType: mimeType, data: data)
    }
}
