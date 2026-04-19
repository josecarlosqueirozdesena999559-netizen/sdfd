import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct MessagingView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @FocusState private var isComposerFocused: Bool
    let onBack: () -> Void
    @State private var keyboardInset: CGFloat = 0
    @State private var messageText = ""
    @State private var selectedThreadID: String?
    @State private var showingFileImporter = false
    @State private var threadSearchText = ""
    @State private var dragOffset: CGFloat = 0
    @StateObject private var recorder = ChatAudioRecorder()
    @State private var pendingAttachment: ChatAttachmentUpload?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if canSwitchThreads && geometry.size.width >= 960 {
                    HStack(spacing: 0) {
                        threadsSidebar
                            .frame(width: 320)

                        Divider()
                            .overlay(AppTheme.fieldBorder.opacity(0.8))

                        conversationSurface
                    }
                } else {
                    VStack(spacing: 0) {
                        topBar

                        if canSwitchThreads {
                            threadInboxStrip(compact: geometry.size.width < 700)
                        }

                        conversationSurface
                    }
                    .offset(y: dragOffset)
                    .scaleEffect(mobileChatScale, anchor: .top)
                    .gesture(chatDismissGesture)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data, .pdf, .image, .audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let fileURL = urls.first else { return }
            Task { pendingAttachment = try? await ChatAttachmentUpload.fromFile(url: fileURL) }
        }
        .task {
            await appDataViewModel.ensureDefaultAdminThread()
            await syncSelectedThreadIfNeeded()
        }
        .onChange(of: appDataViewModel.chatThreads) { _, _ in
            Task { await syncSelectedThreadIfNeeded() }
        }
        .onChange(of: appDataViewModel.activeThreadId) { _, newValue in
            guard let newValue else { return }
            selectedThreadID = newValue
        }
        .onChange(of: messageText) { _, newValue in
            appDataViewModel.updateTypingState(for: selectedThread, text: newValue, isRecording: recorder.isRecording)
        }
        .onChange(of: recorder.isRecording) { _, isRecording in
            appDataViewModel.updateTypingState(for: selectedThread, text: messageText, isRecording: isRecording)
        }
        .onChange(of: selectedThreadID) { _, _ in
            appDataViewModel.stopTyping()
        }
        .onDisappear {
            appDataViewModel.stopTyping()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.minY)
            keyboardInset = max(0, overlap - 12)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardInset = 0
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("Voltar")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(AppTheme.deepBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppTheme.surface)
    }

    private var threadsSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("Início")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.deepBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.fieldBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(filteredThreads.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Text("Conversas")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            SearchFieldRow(prompt: "Buscar conversa", text: $threadSearchText)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if filteredThreads.isEmpty {
                        Text("Nenhuma conversa encontrada.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    } else {
                        ForEach(filteredThreads) { thread in
                            threadRow(thread)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(AppTheme.surface)
    }

    private func threadInboxStrip(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchFieldRow(prompt: "Buscar conversa", text: $threadSearchText)

            if filteredThreads.isEmpty {
                Text("Nenhuma conversa encontrada.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredThreads) { thread in
                            threadPill(thread)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(AppTheme.surface)
    }

    private var conversationSurface: some View {
        Group {
            if let selectedThread {
                VStack(spacing: 0) {
                    conversationHeader(for: selectedThread)
                    messagesPanel
                    composerBar
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chat")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Selecione uma conversa para continuar.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func conversationHeader(for thread: ChatThread) -> some View {
        HStack(spacing: 12) {
            avatarView(for: thread.counterpartName, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.counterpartName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(conversationStatusText(for: thread))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(recorder.isRecording ? AppTheme.danger : AppTheme.textMuted)
            }
            Spacer()
            if thread.hasUnreadMessages { unreadBadge(count: thread.unreadCount) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.fieldBorder.opacity(0.8))
                .frame(height: 1)
        }
    }

    private var messagesPanel: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if appDataViewModel.activeChatMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.textMuted)
                            Text("Ainda não há mensagens nesta conversa.")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(Array(appDataViewModel.activeChatMessages.enumerated()), id: \.element.id) { index, message in
                            if shouldShowDayDivider(at: index) { dayDivider(for: message) }
                            messageRow(message).id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#EAF3FF"), AppTheme.background, AppTheme.fieldFill],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { dismissKeyboard() }
            .onAppear { scrollToBottom(with: proxy) }
            .onChange(of: appDataViewModel.activeChatMessages.count) { _, _ in scrollToBottom(with: proxy) }
        }
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pendingAttachment { attachmentPreview(for: pendingAttachment) }

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    showingFileImporter = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 38, height: 38)
                        .background(AppTheme.fieldFill, in: Circle())
                }
                .buttonStyle(.plain)

                HStack(alignment: .bottom, spacing: 10) {
                    Button { showingFileImporter = true } label: {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)

                    if recorder.isRecording {
                        recordingComposerContent
                    } else {
                        TextField("Digite uma mensagem", text: $messageText, axis: .vertical)
                            .lineLimit(1...5)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                            .tint(AppTheme.deepBlue)
                            .focused($isComposerFocused)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(composerStrokeColor, lineWidth: isComposerFocused || isComposerEmpty == false ? 1.6 : 1)
                )
                .shadow(color: AppTheme.deepBlue.opacity(0.05), radius: 10, y: 2)

                if recorder.isRecording == false && isComposerEmpty == false {
                    Button {
                        guard let selectedThread else { return }
                        Task {
                            await appDataViewModel.sendChatMessage(thread: selectedThread, text: messageText, attachmentUpload: pendingAttachment)
                            messageText = ""
                            pendingAttachment = nil
                            dismissKeyboard()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isComposerEmpty ? AppTheme.textSoft.opacity(0.45) : AppTheme.primaryBlue)
                                .frame(width: 46, height: 46)
                            if appDataViewModel.chatSendInProgress {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: isComposerEmpty ? "mic.fill" : "paperplane.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedThread == nil || isComposerEmpty)
                } else {
                    Button {
                        Task {
                            if recorder.isRecording {
                                pendingAttachment = try? await recorder.stopRecording()
                            } else {
                                try? await recorder.startRecording()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? AppTheme.danger.opacity(0.16) : AppTheme.fieldFill)
                                .frame(width: 46, height: 46)
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(recorder.isRecording ? AppTheme.danger : AppTheme.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, keyboardInset > 0 ? max(8, keyboardInset) : 12)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.fieldBorder.opacity(0.8))
                .frame(height: 1)
        }
        .animation(.easeOut(duration: 0.22), value: keyboardInset)
    }

    private var recordingComposerContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.danger)
                    .frame(width: 8, height: 8)
                Text("Gravando áudio")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(formatTime(recorder.recordingDuration))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }

            ChatWaveformView(
                levels: recorder.waveformLevels,
                progress: 1,
                activeColor: AppTheme.danger,
                inactiveColor: AppTheme.danger.opacity(0.22),
                mirrored: true
            )
            .frame(height: 34)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attachmentPreview(for attachment: ChatAttachmentUpload) -> some View {
        Group {
            if attachment.mimeType.hasPrefix("audio/") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Áudio pronto para revisar")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Escute antes de enviar ou remova se quiser gravar de novo.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                        Button("Remover") { pendingAttachment = nil }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.danger)
                    }

                    ChatAudioClipPlayer(
                        source: .data(attachment.data, "m4a"),
                        title: "Áudio",
                        accentColor: AppTheme.primaryBlue,
                        foregroundColor: AppTheme.textPrimary,
                        backgroundColor: AppTheme.fieldFill,
                        waveformLevels: recorder.lastRecordingLevels,
                        preferredDuration: recorder.lastRecordingDuration
                    )
                }
                .padding(12)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anexo pronto")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(attachment.fileName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Remover") { pendingAttachment = nil }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.danger)
                }
                .padding(12)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isMine = message.senderUserId == appDataViewModel.profile?.id

        return HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 44) }
            if isMine == false { avatarView(for: message.senderName, size: 32) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if isMine == false {
                    Text(message.senderName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textMuted)
                }

                VStack(alignment: .leading, spacing: 8) {
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

                        if let attachment = message.attachment { attachmentView(for: attachment, isMine: isMine) }
                    }

                    HStack(spacing: 8) {
                        if let createdAt = message.createdAt { Text(createdAt.shortBrazilianTime) }
                        if isMine { Image(systemName: message.seenAt == nil ? "checkmark" : "checkmark.circle.fill") }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isMine ? Color.white.opacity(0.78) : AppTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isMine ? Color(hex: "#1877F2") : Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isMine ? Color.clear : AppTheme.fieldBorder, lineWidth: 1))

                if isMine && message.isDeleted == false {
                    Button("Apagar") {
                        Task { await appDataViewModel.deleteOwnMessage(message) }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)

            if isMine == false { Spacer(minLength: 44) }
        }
    }

    @ViewBuilder
    private func attachmentView(for attachment: ChatAttachment, isMine: Bool) -> some View {
        if attachment.isAudio {
            ChatAudioClipPlayer(source: .remote(URL(string: attachment.fileURL)), title: "Áudio", accentColor: isMine ? .white : AppTheme.primaryBlue, foregroundColor: isMine ? .white : AppTheme.textPrimary, backgroundColor: isMine ? Color.white.opacity(0.16) : AppTheme.skyBlue.opacity(0.65))
        } else if let attachmentURL = URL(string: attachment.fileURL) {
            Link(destination: attachmentURL) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.fileName).lineLimit(1)
                        Text("Abrir anexo").font(.system(size: 11, weight: .semibold)).opacity(0.82)
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isMine ? .white : AppTheme.deepBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isMine ? Color.white.opacity(0.16) : AppTheme.skyBlue.opacity(0.65)))
            }
        }
    }

    private func threadRow(_ thread: ChatThread) -> some View {
        Button {
            openThread(thread)
        } label: {
            HStack(spacing: 12) {
                avatarView(for: thread.counterpartName, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(thread.counterpartName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        if thread.hasUnreadMessages { unreadBadge(count: thread.unreadCount) }
                    }
                    Text(displayPreviewText(for: thread.lastMessagePreview))
                        .lineLimit(2)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
                Spacer()
                if let updatedAt = thread.updatedAt {
                    Text(updatedAt.shortBrazilianTime)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSoft)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selectedThreadID == thread.id ? AppTheme.cardBlue : AppTheme.surface))
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
                    if thread.hasUnreadMessages { unreadBadge(count: thread.unreadCount) }
                }
                Text(displayPreviewText(for: thread.lastMessagePreview))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(selectedThreadID == thread.id ? .white : AppTheme.textPrimary)
            .frame(width: 220, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selectedThreadID == thread.id ? AppTheme.deepBlue : Color.white))
        }
        .buttonStyle(.plain)
    }

    private func dayDivider(for message: ChatMessage) -> some View {
        Text(message.createdAt?.shortBrazilianDay ?? "Agora")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppTheme.fieldFill, in: Capsule())
    }

    private func avatarView(for name: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(AppTheme.skyBlue).frame(width: size, height: size)
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

    private func conversationStatusText(for thread: ChatThread) -> String {
        if recorder.isRecording { return "Gravando áudio..." }
        if appDataViewModel.activeTypingIndicator?.threadId == thread.id { return "Digitando..." }
        if let lastSeenDate = latestSeenDate { return "Visto por último \(lastSeenDescription(for: lastSeenDate))" }
        return thread.counterpartRole
    }

    private var latestSeenDate: Date? {
        let myId = appDataViewModel.profile?.id
        let lastCounterpartMessage = appDataViewModel.activeChatMessages.filter { $0.senderUserId != myId }.compactMap(\.createdAt).max()
        let lastSeenOwnMessage = appDataViewModel.activeChatMessages.filter { $0.senderUserId == myId }.compactMap(\.seenAt).max()
        return [lastSeenOwnMessage, lastCounterpartMessage].compactMap { $0 }.max()
    }

    private func lastSeenDescription(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "hoje as \(date.shortBrazilianTime)" }
        if calendar.isDateInYesterday(date) { return "ontem as \(date.shortBrazilianTime)" }
        return date.shortBrazilianDateTime
    }

    private func openThread(_ thread: ChatThread) {
        selectedThreadID = thread.id
        Task { try? await appDataViewModel.loadMessages(for: thread.id) }
    }

    private func syncSelectedThreadIfNeeded() async {
        if let activeThreadId = appDataViewModel.activeThreadId, appDataViewModel.chatThreads.contains(where: { $0.id == activeThreadId }) {
            selectedThreadID = activeThreadId
            return
        }
        if let selectedThreadID, appDataViewModel.chatThreads.contains(where: { $0.id == selectedThreadID }) { return }
        guard let nextThread = appDataViewModel.chatThreads.first else {
            selectedThreadID = nil
            return
        }
        selectedThreadID = nextThread.id
        try? await appDataViewModel.loadMessages(for: nextThread.id)
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        guard let lastMessage = appDataViewModel.activeChatMessages.last else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
        }
    }

    private func dismissKeyboard() {
        isComposerFocused = false
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "00:00" }
        let totalSeconds = Int(value.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func shouldShowDayDivider(at index: Int) -> Bool {
        guard let currentDate = appDataViewModel.activeChatMessages[index].createdAt else { return index == 0 }
        guard index > 0, let previousDate = appDataViewModel.activeChatMessages[index - 1].createdAt else { return true }
        return Calendar.current.isDate(currentDate, inSameDayAs: previousDate) == false
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let joined = parts.compactMap { $0.first }.map(String.init).joined()
        return joined.isEmpty ? "AD" : joined.uppercased()
    }

    private func displayPreviewText(for rawValue: String) -> String {
        let normalized = rawValue.normalizedSearchText
        if normalized == "audio.m4a" || normalized == "audio enviado" {
            return "Áudio"
        }
        return rawValue
    }

    private var composerStrokeColor: Color {
        if recorder.isRecording {
            return AppTheme.danger.opacity(0.65)
        }
        if isComposerFocused || isComposerEmpty == false {
            return AppTheme.primaryBlue.opacity(0.75)
        }
        return AppTheme.fieldBorder
    }

    private var mobileChatScale: CGFloat {
        guard dragOffset > 0 else { return 1 }
        return max(0.96, 1 - (dragOffset / 2200))
    }

    private var chatDismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                guard shouldTrackDismissDrag(value) else { return }
                dragOffset = min(max(0, value.translation.height), 140)
            }
            .onEnded { value in
                handleDismissDragEnded(value)
            }
    }

    private func shouldTrackDismissDrag(_ value: DragGesture.Value) -> Bool {
        let vertical = value.translation.height
        let horizontal = abs(value.translation.width)
        return vertical > 0 && vertical > horizontal
    }

    private func handleDismissDragEnded(_ value: DragGesture.Value) {
        defer {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                dragOffset = 0
            }
        }

        guard shouldTrackDismissDrag(value) else { return }

        let shouldDismissKeyboard = keyboardInset > 0 || isComposerFocused
        if shouldDismissKeyboard {
            dismissKeyboard()
            return
        }

        if value.translation.height > 90 {
            onBack()
        }
    }

    private var canSwitchThreads: Bool { appDataViewModel.canCurrentUserSwitchChatThreads }
    private var selectedThread: ChatThread? { appDataViewModel.chatThreads.first { $0.id == selectedThreadID } }
    private var filteredThreads: [ChatThread] {
        let search = threadSearchText.normalizedSearchText
        guard search.isEmpty == false else { return appDataViewModel.chatThreads }
        return appDataViewModel.chatThreads.filter {
            $0.counterpartName.normalizedSearchText.contains(search)
                || $0.counterpartRole.normalizedSearchText.contains(search)
                || $0.lastMessagePreview.normalizedSearchText.contains(search)
        }
    }
    private var isComposerEmpty: Bool { messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachment == nil }
}

private enum ChatAudioSource { case remote(URL?), data(Data, String) }

@MainActor
private final class ChatAudioPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    private let source: ChatAudioSource
    private var audioPlayer: AVAudioPlayer?
    private var localURL: URL?
    private var timer: Timer?

    init(source: ChatAudioSource) { self.source = source }

    func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            stopTimer()
            return
        }
        Task { await play() }
    }

    private func play() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fileURL = try await prepareFileURL()
            if audioPlayer == nil || audioPlayer?.url != fileURL {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                duration = audioPlayer?.duration ?? 0
            }
            audioPlayer?.play()
            isPlaying = true
            startTimer()
        } catch {
            isPlaying = false
        }
    }

    private func prepareFileURL() async throws -> URL {
        if let localURL { return localURL }
        switch source {
        case .remote(let url):
            guard let url else { throw NSError(domain: "ChatAudioPlayback", code: 1) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            try data.write(to: finalURL, options: .atomic)
            localURL = finalURL
            return finalURL
        case .data(let data, let ext):
            let finalURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try data.write(to: finalURL, options: .atomic)
            localURL = finalURL
            return finalURL
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self, let audioPlayer else { return }
            self.currentTime = audioPlayer.currentTime
            self.duration = audioPlayer.duration
            self.isPlaying = audioPlayer.isPlaying
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
}

private struct ChatAudioClipPlayer: View {
    let title: String
    let accentColor: Color
    let foregroundColor: Color
    let backgroundColor: Color
    let waveformLevels: [CGFloat]
    let preferredDuration: TimeInterval?
    @StateObject private var controller: ChatAudioPlaybackController

    init(
        source: ChatAudioSource,
        title: String,
        accentColor: Color,
        foregroundColor: Color,
        backgroundColor: Color,
        waveformLevels: [CGFloat] = ChatWaveformView.defaultLevels,
        preferredDuration: TimeInterval? = nil
    ) {
        self.title = title
        self.accentColor = accentColor
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.waveformLevels = waveformLevels
        self.preferredDuration = preferredDuration
        _controller = StateObject(wrappedValue: ChatAudioPlaybackController(source: source))
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { controller.togglePlayback() } label: {
                ZStack {
                    Circle().fill(accentColor.opacity(0.14)).frame(width: 36, height: 36)
                    if controller.isLoading {
                        ProgressView().tint(accentColor)
                    } else {
                        Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(formatTime(controller.currentTime)) / \(formatTime(displayDuration))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(foregroundColor.opacity(0.78))
                }

                ChatWaveformView(
                    levels: waveformLevels,
                    progress: playbackProgress,
                    activeColor: accentColor,
                    inactiveColor: foregroundColor.opacity(0.22),
                    mirrored: false
                )
                .frame(height: 28)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var displayDuration: TimeInterval {
        if controller.duration > 0 { return controller.duration }
        return preferredDuration ?? 0
    }

    private var playbackProgress: CGFloat {
        guard displayDuration > 0 else { return controller.isPlaying ? 0.08 : 0 }
        return CGFloat(min(max(controller.currentTime / displayDuration, 0), 1))
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "00:00" }
        let totalSeconds = Int(value.rounded())
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct ChatWaveformView: View {
    let levels: [CGFloat]
    let progress: CGFloat
    let activeColor: Color
    let inactiveColor: Color
    let mirrored: Bool

    static let defaultLevels: [CGFloat] = [
        7, 11, 15, 10, 18, 22, 16, 12, 20, 25, 17, 13, 21, 26, 19, 12,
        9, 14, 23, 17, 12, 20, 24, 16, 11, 18, 22, 15, 10, 16, 13, 9
    ]

    var body: some View {
        GeometryReader { geometry in
            let count = max(levels.count, 1)
            let totalSpacing = CGFloat(count - 1) * 3
            let barWidth = max((geometry.size.width - totalSpacing) / CGFloat(count), 2)
            let highlightedBars = Int(round(CGFloat(count) * min(max(progress, 0), 1)))

            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(index < highlightedBars ? activeColor : inactiveColor)
                        .frame(width: barWidth, height: max(6, level))
                        .frame(maxHeight: .infinity, alignment: .center)
                        .scaleEffect(x: 1, y: mirrored ? -1 : 1, anchor: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

@MainActor
final class ChatAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var waveformLevels = Array(repeating: CGFloat(6), count: 32)
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var lastRecordingLevels = ChatWaveformView.defaultLevels
    @Published private(set) var lastRecordingDuration: TimeInterval = 0
    private var audioRecorder: AVAudioRecorder?
    private var currentURL: URL?
    private var meterTimer: Timer?

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        if await requestMicrophonePermission() == false {
            throw NSError(domain: "ChatAudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permissão de microfone negada."])
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
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()
        currentURL = url
        waveformLevels = Array(repeating: CGFloat(6), count: 32)
        recordingDuration = 0
        isRecording = true
        startMetering()
    }

    func stopRecording() async throws -> ChatAttachmentUpload? {
        stopMetering()
        audioRecorder?.stop()
        isRecording = false

        guard let currentURL else { return nil }
        let data = try Data(contentsOf: currentURL)
        lastRecordingLevels = waveformLevels
        lastRecordingDuration = recordingDuration
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

    private func startMetering() {
        stopMetering()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let audioRecorder = self.audioRecorder else { return }
            audioRecorder.updateMeters()
            self.recordingDuration = audioRecorder.currentTime
            self.waveformLevels.removeFirst()
            self.waveformLevels.append(self.normalizePower(audioRecorder.averagePower(forChannel: 0)))
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func normalizePower(_ power: Float) -> CGFloat {
        let minDb: Float = -60
        let clamped = max(power, minDb)
        let normalized = (clamped - minDb) / abs(minDb)
        return max(6, CGFloat(normalized) * 28)
    }
}

private extension ChatAttachmentUpload {
    static func fromFile(url: URL) async throws -> ChatAttachmentUpload {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return ChatAttachmentUpload(fileName: url.lastPathComponent, mimeType: mimeType, data: data)
    }
}
