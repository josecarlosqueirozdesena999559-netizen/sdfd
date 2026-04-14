import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct MessagingView: View {
    @EnvironmentObject private var appDataViewModel: AppDataViewModel
    @State private var messageText = ""
    @State private var selectedThreadID: String?
    @State private var showingFileImporter = false
    @StateObject private var recorder = ChatAudioRecorder()
    @State private var pendingAttachment: ChatAttachmentUpload?

    var body: some View {
        ScreenContainer(title: "", subtitle: "") {
            summaryCard
            threadPickerCard
            messagesCard
            composerCard
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
            if let activeThreadId = appDataViewModel.activeThreadId,
               appDataViewModel.chatThreads.contains(where: { $0.id == activeThreadId }) {
                selectedThreadID = activeThreadId
            } else if selectedThread == nil, let firstThread = appDataViewModel.chatThreads.first {
                selectedThreadID = firstThread.id
                try? await appDataViewModel.loadMessages(for: firstThread.id)
            }
        }
        .onChange(of: appDataViewModel.chatThreads) { _, newThreads in
            if let activeThreadId = appDataViewModel.activeThreadId,
               newThreads.contains(where: { $0.id == activeThreadId }) {
                selectedThreadID = activeThreadId
                return
            }

            guard selectedThread == nil, let firstThread = newThreads.first else {
                return
            }

            selectedThreadID = firstThread.id
            Task {
                try? await appDataViewModel.loadMessages(for: firstThread.id)
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
                title: "Canal com a administração",
                subtitle: "Usuários falam apenas com administradores. As mensagens chegam em tempo real."
            )

            HStack(spacing: 12) {
                InfoStrip(
                    icon: "person.2.fill",
                    title: "Conversas",
                    value: "\(appDataViewModel.chatThreads.count)"
                )

                InfoStrip(
                    icon: "bell.badge.fill",
                    title: "Não lidas",
                    value: "\(appDataViewModel.unreadNotificationCount)"
                )
            }
        }
    }

    private var threadPickerCard: some View {
        PrimaryCard {
            SectionHeader(title: "Atendimentos")

            if appDataViewModel.chatThreads.isEmpty {
                Text("Nenhum atendimento foi iniciado ainda.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(appDataViewModel.chatThreads) { thread in
                            Button {
                                selectedThreadID = thread.id
                                Task {
                                    try? await appDataViewModel.loadMessages(for: thread.id)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(thread.counterpartName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(selectedThreadID == thread.id ? .white : AppTheme.textPrimary)

                                    Text(thread.counterpartRole)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selectedThreadID == thread.id ? Color.white.opacity(0.85) : AppTheme.textMuted)

                                    Text(thread.lastMessagePreview)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(selectedThreadID == thread.id ? Color.white.opacity(0.92) : AppTheme.textMuted)
                                        .lineLimit(2)
                                }
                                .frame(width: 220, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selectedThreadID == thread.id ? AppTheme.deepBlue : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selectedThreadID == thread.id ? AppTheme.deepBlue : AppTheme.fieldBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var messagesCard: some View {
        PrimaryCard {
            SectionHeader(
                title: selectedThread?.title ?? "Mensagens",
                subtitle: selectedThread?.updatedAt?.shortBrazilianDateTime ?? "Abra um atendimento para conversar."
            )

            if appDataViewModel.activeChatMessages.isEmpty {
                Text("Ainda não há mensagens nesta conversa.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(appDataViewModel.activeChatMessages) { message in
                            messageBubble(message)
                        }
                    }
                }
                .frame(minHeight: 260, maxHeight: 420)
            }
        }
    }

    private var composerCard: some View {
        PrimaryCard {
            SectionHeader(title: "Responder")

            if let pendingAttachment {
                SoftPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anexo pronto")
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

            TextField("Digite sua mensagem", text: $messageText, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.fieldBorder, lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button {
                    showingFileImporter = true
                } label: {
                    composerActionLabel(systemImage: "paperclip", title: "Anexar")
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
                        title: recorder.isRecording ? "Parar áudio" : "Áudio"
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
                .disabled(selectedThread == nil || (messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachment == nil))
                .opacity(selectedThread == nil ? 0.6 : 1)
            }
        }
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

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderUserId == appDataViewModel.profile?.id

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
            HStack {
                if isMine { Spacer() }

                VStack(alignment: .leading, spacing: 8) {
                    Text(message.senderName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isMine ? Color.white.opacity(0.88) : AppTheme.deepBlue)

                    if message.isDeleted {
                        Text("Mensagem apagada")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isMine ? Color.white.opacity(0.82) : AppTheme.textMuted)
                    } else {
                        if message.text.isEmpty == false {
                            Text(message.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isMine ? .white : AppTheme.textPrimary)
                        }

                        if let attachment = message.attachment, let attachmentURL = URL(string: attachment.fileURL) {
                            Link(destination: attachmentURL) {
                                HStack(spacing: 8) {
                                    Image(systemName: attachment.isAudio ? "waveform" : "paperclip")
                                    Text(attachment.fileName)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(isMine ? .white : AppTheme.deepBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isMine ? Color.white.opacity(0.16) : AppTheme.skyBlue.opacity(0.65))
                                )
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        if let createdAt = message.createdAt {
                            Text(createdAt.shortBrazilianDateTime)
                        }

                        if isMine {
                            Text(message.seenAt == nil ? "Enviado" : "Visto")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isMine ? Color.white.opacity(0.75) : AppTheme.textMuted)

                    if isMine && message.isDeleted == false {
                        Button("Apagar mensagem") {
                            Task {
                                await appDataViewModel.deleteOwnMessage(message)
                            }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isMine ? Color.white.opacity(0.92) : AppTheme.danger)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isMine ? AppTheme.deepBlue : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isMine ? AppTheme.deepBlue : AppTheme.fieldBorder, lineWidth: 1)
                )

                if isMine == false { Spacer() }
            }
        }
    }

    private var selectedThread: ChatThread? {
        appDataViewModel.chatThreads.first { $0.id == selectedThreadID }
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
