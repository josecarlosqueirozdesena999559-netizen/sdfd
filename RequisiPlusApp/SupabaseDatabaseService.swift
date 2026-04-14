import Foundation

enum SupabaseDatabaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Não foi possível montar a URL do banco."
        case .invalidResponse:
            return "Resposta inválida do banco."
        case .requestFailed(let message):
            return message
        }
    }
}

struct SupabaseDatabaseService {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUserProfile(session userSession: UserSession) async throws -> UserProfile {
        let authUserId = userSession.user.id
        let encodedAuthUserId = authUserId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authUserId
        let primaryPath = "/rest/v1/usuarios?select=id,nome,email,setor,cpf,role,funcao,auth_user_id,categorias_permitidas&auth_user_id=eq.\(encodedAuthUserId)&limit=1"

        if let profile: UsuarioRecord = try await fetchFirst(path: primaryPath, accessToken: userSession.accessToken) {
            return profile.toDomain()
        }

        if let email = userSession.user.email, email.isEmpty == false {
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            let fallbackPath = "/rest/v1/usuarios?select=id,nome,email,setor,cpf,role,funcao,auth_user_id,categorias_permitidas&email=eq.\(encodedEmail)&limit=1"
            if let profile: UsuarioRecord = try await fetchFirst(path: fallbackPath, accessToken: userSession.accessToken) {
                return profile.toDomain()
            }
        }

        throw SupabaseDatabaseError.requestFailed("Usuário autenticado não encontrado na tabela usuarios.")
    }

    func fetchRequisitions(session userSession: UserSession, profile: UserProfile) async throws -> [Requisition] {
        let encodedName = profile.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? profile.name
        let encodedSetor = profile.setor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? profile.setor
        let path = "/rest/v1/requisicoes?select=*&solicitante=eq.\(encodedName)&setor=eq.\(encodedSetor)&order=created_at.desc"
        let records: [RequisicaoRecord] = try await perform(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.enumerated().map { index, record in
            record.toDomain(position: index)
        }
    }

    func fetchCatalogItems(session userSession: UserSession, categories: [String]) async throws -> [MaterialCatalogItem] {
        guard categories.isEmpty == false else {
            return []
        }

        let encodedCategories = categories
            .map { "\"\($0)\"" }
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: ",")

        let path = "/rest/v1/itens?select=id,nome,unidade,categoria,subcategoria&categoria=in.(\(encodedCategories))&order=nome.asc"
        let records: [CatalogItemRecord] = try await perform(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.map { $0.toDomain() }
    }

    func fetchNotifications(session userSession: UserSession, profile: UserProfile) async throws -> [NotificationItem] {
        let path = "/rest/v1/user_notifications?select=id,title,body,created_at,is_read,target_thread_id&user_id=eq.\(profile.id)&order=created_at.desc"
        let records: [NotificationRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.map { $0.toDomain() }
    }

    func fetchAdminContacts(session userSession: UserSession) async throws -> [ChatContact] {
        let path = "/rest/v1/usuarios?select=id,nome,role,setor&role=ilike.*admin*&order=nome.asc"
        let records: [ChatContactRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.map { $0.toDomain() }
    }

    func fetchChatThreads(session userSession: UserSession, profile: UserProfile) async throws -> [ChatThread] {
        let path: String

        if profile.isAdmin {
            path = "/rest/v1/chat_threads?select=*&order=updated_at.desc"
        } else {
            path = "/rest/v1/chat_threads?select=*&requester_user_id=eq.\(profile.id)&order=updated_at.desc"
        }

        let records: [ChatThreadRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.map { $0.toDomain(for: profile) }
    }

    func fetchChatMessages(session userSession: UserSession, threadId: String) async throws -> [ChatMessage] {
        let path = "/rest/v1/chat_messages?select=*&thread_id=eq.\(threadId)&order=created_at.asc"
        let records: [ChatMessageRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.map { $0.toDomain() }
    }

    func ensureChatThread(
        session userSession: UserSession,
        profile: UserProfile,
        adminContact: ChatContact
    ) async throws -> ChatThread {
        let path = "/rest/v1/chat_threads?select=*&requester_user_id=eq.\(profile.id)&admin_user_id=eq.\(adminContact.id)&limit=1"

        if let existing: ChatThreadRecord = try await fetchFirstOptional(path: path, accessToken: userSession.accessToken) {
            return existing.toDomain(for: profile)
        }

        let payload = NewChatThreadPayload(
            requesterUserId: profile.id,
            requesterName: profile.name,
            requesterRole: profile.role,
            adminUserId: adminContact.id,
            adminName: adminContact.name,
            adminRole: adminContact.role,
            title: "Atendimento administrativo",
            lastMessagePreview: "Conversa iniciada"
        )

        let records: [ChatThreadRecord] = try await perform(
            path: "/rest/v1/chat_threads?select=*",
            method: "POST",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )

        guard let thread = records.first else {
            throw SupabaseDatabaseError.requestFailed("Não foi possível criar a conversa com a administração.")
        }

        return thread.toDomain(for: profile)
    }

    func sendChatMessage(
        session userSession: UserSession,
        profile: UserProfile,
        thread: ChatThread,
        text: String,
        attachmentUpload: ChatAttachmentUpload?
    ) async throws -> ChatMessage {
        let attachment = try await uploadAttachmentIfNeeded(session: userSession, profile: profile, upload: attachmentUpload)

        let payload = NewChatMessagePayload(
            threadId: thread.id,
            senderUserId: profile.id,
            senderName: profile.name,
            senderRole: profile.role,
            recipientUserId: thread.counterpartUserId,
            body: text.trimmingCharacters(in: .whitespacesAndNewlines),
            attachmentName: attachment?.fileName,
            attachmentURL: attachment?.fileURL,
            attachmentMimeType: attachment?.mimeType,
            attachmentStoragePath: attachment?.storagePath
        )

        let records: [ChatMessageRecord] = try await perform(
            path: "/rest/v1/chat_messages?select=*",
            method: "POST",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )

        guard let message = records.first else {
            throw SupabaseDatabaseError.requestFailed("Não foi possível enviar a mensagem.")
        }

        let updatePayload = ChatThreadUpdatePayload(
            updatedAt: AppDateFormatter.iso8601Basic.string(from: Date()),
            lastMessagePreview: payload.body.isEmpty ? attachment?.fileName ?? "Áudio enviado" : payload.body
        )

        let _: [ChatThreadRecord] = try await perform(
            path: "/rest/v1/chat_threads?id=eq.\(thread.id)&select=*",
            method: "PATCH",
            accessToken: userSession.accessToken,
            body: updatePayload,
            preferRepresentation: true
        )

        let notificationPayload = NewNotificationPayload(
            userId: thread.counterpartUserId,
            title: "Nova mensagem",
            body: "\(profile.name) enviou uma nova mensagem.",
            targetThreadId: thread.id
        )

        let _: [NotificationRecord] = try await performOptional(
            path: "/rest/v1/user_notifications?select=id",
            method: "POST",
            accessToken: userSession.accessToken,
            body: notificationPayload,
            preferRepresentation: true
        )

        return message.toDomain()
    }

    func markThreadMessagesAsSeen(
        session userSession: UserSession,
        profile: UserProfile,
        threadId: String
    ) async throws {
        let payload = SeenMessagePayload(seenAt: AppDateFormatter.iso8601Basic.string(from: Date()))
        let _: [ChatMessageRecord] = try await performOptional(
            path: "/rest/v1/chat_messages?thread_id=eq.\(threadId)&recipient_user_id=eq.\(profile.id)&seen_at=is.null&select=*",
            method: "PATCH",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )
    }

    func markNotificationAsRead(session userSession: UserSession, notificationId: String) async throws {
        let payload = ReadNotificationPayload(isRead: true)
        let _: [NotificationRecord] = try await performOptional(
            path: "/rest/v1/user_notifications?id=eq.\(notificationId)&select=id",
            method: "PATCH",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )
    }

    func deleteOwnMessage(session userSession: UserSession, messageId: String) async throws {
        let payload = DeleteMessagePayload(deletedAt: AppDateFormatter.iso8601Basic.string(from: Date()))
        let _: [ChatMessageRecord] = try await performOptional(
            path: "/rest/v1/chat_messages?id=eq.\(messageId)&select=*",
            method: "PATCH",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )
    }

    func createRequisition(
        session userSession: UserSession,
        profile: UserProfile,
        materialType: MaterialType,
        entries: [RequestedItemEntry],
        observation: String
    ) async throws -> Requisition {
        let generatedCode = makeRequisitionCode()
        let itemPayload = entries.enumerated().map { index, entry in
            RequisitionItemPayload(
                item: entry.item.name,
                need: numericValue(from: entry.requestedQuantity),
                unit: entry.item.unit,
                ordem: index,
                stock: numericValue(from: entry.currentBalance),
                itemId: entry.item.id,
                provided: 0,
                subcategoria: entry.item.subcategory
            )
        }

        let payload = NewRequisitionPayload(
            setor: profile.setor,
            solicitante: profile.name,
            categoria: materialType.title,
            data: DateFormatter.requisitionDate.string(from: Date()),
            items: Self.encodeJSONString(itemPayload),
            status: "aguardando_assinatura_requisicao",
            codigo: generatedCode,
            numeroRequisicao: generatedCode,
            numeroSolicitacao: generatedCode,
            solicitanteCpf: profile.cpf,
            solicitanteFuncao: profile.funcao,
            devolucaoMotivo: buildObservation(
                observation: observation,
                entries: entries
            )
        )

        let records: [RequisicaoRecord] = try await perform(
            path: "/rest/v1/requisicoes?select=*",
            method: "POST",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )

        guard let record = records.first else {
            throw SupabaseDatabaseError.requestFailed("Não foi possível confirmar a criação da requisição.")
        }

        let itemRows = entries.enumerated().map { index, entry in
            RequisitionItemInsertPayload(
                requisicaoId: record.id,
                ordem: index,
                itemId: entry.item.id,
                nome: entry.item.name,
                unidade: entry.item.unit,
                subcategoria: entry.item.subcategory,
                qtdDisponivel: numericValue(from: entry.currentBalance),
                qtdNecessaria: numericValue(from: entry.requestedQuantity),
                qtdFornecida: nil
            )
        }

        if itemRows.isEmpty == false {
            let _: [RequisitionItemInsertResult] = try await perform(
                path: "/rest/v1/requisicao_itens?select=id",
                method: "POST",
                accessToken: userSession.accessToken,
                body: itemRows,
                preferRepresentation: true
            )
        }

        return record.toDomain(position: 0)
    }

    private static func encodeJSONString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func fetchFirst<Response: Decodable>(path: String, accessToken: String) async throws -> Response? {
        let results: [Response] = try await perform(path: path, method: "GET", accessToken: accessToken)
        return results.first
    }

    private func fetchFirstOptional<Response: Decodable>(path: String, accessToken: String) async throws -> Response? {
        let results: [Response] = try await performOptional(path: path, method: "GET", accessToken: accessToken)
        return results.first
    }

    private func perform<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String
    ) async throws -> Response {
        try await performWithRequest(
            path: path,
            method: method,
            accessToken: accessToken,
            bodyData: nil,
            preferRepresentation: false
        )
    }

    private func performOptional<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String
    ) async throws -> Response {
        do {
            return try await perform(path: path, method: method, accessToken: accessToken)
        } catch let error as SupabaseDatabaseError {
            if case .requestFailed(let message) = error, isMissingRelationMessage(message), let empty = emptyValue(for: Response.self) {
                return empty
            }
            throw error
        }
    }

    private func perform<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String,
        body: Body,
        preferRepresentation: Bool = false
    ) async throws -> Response {
        let bodyData = try encoder.encode(body)
        return try await performWithRequest(
            path: path,
            method: method,
            accessToken: accessToken,
            bodyData: bodyData,
            preferRepresentation: preferRepresentation
        )
    }

    private func performOptional<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String,
        body: Body,
        preferRepresentation: Bool = false
    ) async throws -> Response {
        do {
            return try await perform(
                path: path,
                method: method,
                accessToken: accessToken,
                body: body,
                preferRepresentation: preferRepresentation
            )
        } catch let error as SupabaseDatabaseError {
            if case .requestFailed(let message) = error, isMissingRelationMessage(message), let empty = emptyValue(for: Response.self) {
                return empty
            }
            throw error
        }
    }

    private func performWithRequest<Response: Decodable>(
        path: String,
        method: String,
        accessToken: String,
        bodyData: Data?,
        preferRepresentation: Bool
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: SupabaseConfig.url) else {
            throw SupabaseDatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }

        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseDatabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(AuthErrorResponse.self, from: data).readableMessage)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SupabaseDatabaseError.requestFailed(message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SupabaseDatabaseError.requestFailed("Não foi possível interpretar os dados do banco.")
        }
    }

    private func uploadAttachmentIfNeeded(
        session userSession: UserSession,
        profile: UserProfile,
        upload: ChatAttachmentUpload?
    ) async throws -> ChatAttachment? {
        guard let upload else {
            return nil
        }

        let sanitizedName = upload.fileName.replacingOccurrences(of: " ", with: "_")
        let filePath = "chat/\(profile.id)/\(UUID().uuidString)-\(sanitizedName)"
        let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath

        guard let url = URL(string: "/storage/v1/object/chat-uploads/\(encodedPath)", relativeTo: SupabaseConfig.url) else {
            throw SupabaseDatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(userSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(upload.mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        request.httpBody = upload.data

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseDatabaseError.requestFailed("Não foi possível enviar o anexo para o armazenamento.")
        }

        return ChatAttachment(
            fileName: upload.fileName,
            fileURL: "\(SupabaseConfig.url.absoluteString)/storage/v1/object/public/chat-uploads/\(filePath)",
            mimeType: upload.mimeType,
            storagePath: filePath
        )
    }

    private func emptyValue<Response: Decodable>(for _: Response.Type) -> Response? {
        if Response.self == [NotificationRecord].self {
            return [] as? Response
        }
        if Response.self == [ChatContactRecord].self {
            return [] as? Response
        }
        if Response.self == [ChatThreadRecord].self {
            return [] as? Response
        }
        if Response.self == [ChatMessageRecord].self {
            return [] as? Response
        }
        return nil
    }

    private func isMissingRelationMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("relation")
            || normalized.contains("does not exist")
            || normalized.contains("could not find")
            || normalized.contains("404")
    }
}

private func makeRequisitionCode(now: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "pt_BR")
    formatter.dateFormat = "ddMMyyHHmmss"
    return formatter.string(from: now)
}

private func buildObservation(observation: String, entries: [RequestedItemEntry]) -> String? {
    var parts = entries.map {
        "\($0.item.name) (saldo_atual: \($0.currentBalance), quantidade: \($0.requestedQuantity))"
    }

    if observation.isEmpty == false {
        parts.append("Observacao: \(observation)")
    }

    guard parts.isEmpty == false else {
        return nil
    }

    return parts.joined(separator: " | ")
}

private struct UsuarioRecord: Decodable {
    let id: String
    let nome: String
    let email: String?
    let setor: String
    let cpf: String?
    let role: String
    let funcao: String?
    let authUserId: String?
    let categoriasPermitidas: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case nome
        case email
        case setor
        case cpf
        case role
        case funcao
        case authUserId = "auth_user_id"
        case categoriasPermitidas = "categorias_permitidas"
    }

    func toDomain() -> UserProfile {
        UserProfile(
            id: id,
            authUserId: authUserId,
            name: nome,
            email: email,
            setor: setor,
            cpf: cpf,
            role: role,
            funcao: funcao,
            categoriasPermitidas: categoriasPermitidas ?? []
        )
    }
}

private struct CatalogItemRecord: Decodable {
    let id: String
    let nome: String
    let unidade: String
    let categoria: String
    let subcategoria: String?

    func toDomain() -> MaterialCatalogItem {
        MaterialCatalogItem(
            id: id,
            categoryId: categoria,
            name: nome,
            unit: unidade,
            subcategory: subcategoria
        )
    }
}

struct ChatAttachmentUpload {
    let fileName: String
    let mimeType: String
    let data: Data
}

private struct NotificationRecord: Decodable {
    let id: String
    let title: String
    let body: String
    let createdAt: String?
    let isRead: Bool?
    let targetThreadId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt = "created_at"
        case isRead = "is_read"
        case targetThreadId = "target_thread_id"
    }

    func toDomain() -> NotificationItem {
        NotificationItem(
            id: id,
            title: title,
            body: body,
            createdAt: AppDateFormatter.parse(dateString: createdAt),
            isRead: isRead ?? false,
            targetThreadId: targetThreadId
        )
    }
}

private struct ChatContactRecord: Decodable {
    let id: String
    let nome: String
    let role: String
    let setor: String?

    func toDomain() -> ChatContact {
        ChatContact(
            id: id,
            name: nome,
            role: role,
            setor: setor ?? "Não informado"
        )
    }
}

private struct ChatThreadRecord: Decodable {
    let id: String
    let title: String?
    let requesterUserId: String
    let requesterName: String
    let requesterRole: String?
    let adminUserId: String
    let adminName: String
    let adminRole: String?
    let lastMessagePreview: String?
    let updatedAt: String?
    let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case requesterUserId = "requester_user_id"
        case requesterName = "requester_name"
        case requesterRole = "requester_role"
        case adminUserId = "admin_user_id"
        case adminName = "admin_name"
        case adminRole = "admin_role"
        case lastMessagePreview = "last_message_preview"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }

    func toDomain(for profile: UserProfile) -> ChatThread {
        let showingAdmin = profile.id == requesterUserId
        let counterpartName = showingAdmin ? adminName : requesterName
        let counterpartRole = showingAdmin ? (adminRole ?? "Administrador") : (requesterRole ?? "Usuário")
        let counterpartUserId = showingAdmin ? adminUserId : requesterUserId

        return ChatThread(
            id: id,
            title: title ?? counterpartName,
            counterpartName: counterpartName,
            counterpartRole: counterpartRole,
            counterpartUserId: counterpartUserId,
            lastMessagePreview: lastMessagePreview ?? "Conversa sem mensagens ainda.",
            updatedAt: AppDateFormatter.parse(dateString: updatedAt),
            unreadCount: unreadCount ?? 0
        )
    }
}

private struct ChatMessageRecord: Decodable {
    let id: String
    let threadId: String
    let senderUserId: String
    let senderName: String
    let body: String?
    let createdAt: String?
    let seenAt: String?
    let deletedAt: String?
    let attachmentName: String?
    let attachmentURL: String?
    let attachmentMimeType: String?
    let attachmentStoragePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderUserId = "sender_user_id"
        case senderName = "sender_name"
        case body
        case createdAt = "created_at"
        case seenAt = "seen_at"
        case deletedAt = "deleted_at"
        case attachmentName = "attachment_name"
        case attachmentURL = "attachment_url"
        case attachmentMimeType = "attachment_mime_type"
        case attachmentStoragePath = "attachment_storage_path"
    }

    func toDomain() -> ChatMessage {
        let attachment: ChatAttachment?
        if let attachmentName, let attachmentURL, let attachmentMimeType {
            attachment = ChatAttachment(
                fileName: attachmentName,
                fileURL: attachmentURL,
                mimeType: attachmentMimeType,
                storagePath: attachmentStoragePath
            )
        } else {
            attachment = nil
        }

        return ChatMessage(
            id: id,
            threadId: threadId,
            senderUserId: senderUserId,
            senderName: senderName,
            text: body ?? "",
            createdAt: AppDateFormatter.parse(dateString: createdAt),
            seenAt: AppDateFormatter.parse(dateString: seenAt),
            deletedAt: AppDateFormatter.parse(dateString: deletedAt),
            attachment: attachment
        )
    }
}

private struct RequisicaoRecord: Decodable {
    let id: String
    let saidaCodigo: String?
    let categoria: String
    let setor: String
    let solicitante: String
    let status: String
    let data: String
    let createdAt: String?
    let signedAttachment: JSONValue?
    let timestamp: Int64?
    let numero: JSONValue?
    let codigo: JSONValue?
    let numeroRequisicao: JSONValue?
    let numeroSolicitacao: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case saidaCodigo = "saida_codigo"
        case categoria
        case setor
        case solicitante
        case status
        case data
        case createdAt = "created_at"
        case signedAttachment = "signed_attachment"
        case timestamp
        case numero
        case codigo
        case numeroRequisicao = "numero_requisicao"
        case numeroSolicitacao = "numero_solicitacao"
    }

    func toDomain(position: Int) -> Requisition {
        Requisition(
            id: id,
            code: resolvedCode(fallbackPosition: position),
            materialType: categoria,
            sector: setor,
            requestedBy: solicitante,
            status: status,
            date: data,
            requiresDesktopSignature: signedAttachment == nil && status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains("assin")
        )
    }

    private func resolvedCode(fallbackPosition: Int) -> String {
        let realCode = [
            saidaCodigo,
            numero?.displayText,
            codigo?.displayText,
            numeroRequisicao?.displayText,
            numeroSolicitacao?.displayText
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { $0.isEmpty == false }

        if let realCode {
            return realCode
        }

        return "REQ-\(String(format: "%04d", (timestamp ?? Int64(fallbackPosition + 1)) % 10000))"
    }
}

private struct NewRequisitionPayload: Encodable {
    let setor: String
    let solicitante: String
    let categoria: String
    let data: String
    let items: String
    let status: String
    let codigo: String
    let numeroRequisicao: String
    let numeroSolicitacao: String
    let solicitanteCpf: String?
    let solicitanteFuncao: String?
    let devolucaoMotivo: String?

    enum CodingKeys: String, CodingKey {
        case setor
        case solicitante
        case categoria
        case data
        case items
        case status
        case codigo
        case numeroRequisicao = "numero_requisicao"
        case numeroSolicitacao = "numero_solicitacao"
        case solicitanteCpf = "solicitante_cpf"
        case solicitanteFuncao = "solicitante_funcao"
        case devolucaoMotivo = "devolucao_motivo"
    }
}

private extension DateFormatter {
    static let requisitionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
}

private extension JSONValue {
    var displayText: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        default:
            return nil
        }
    }
}

private func numericValue(from rawValue: String) -> Double {
    let normalized = rawValue
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: ",", with: ".")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return Double(normalized) ?? 0
}

private struct NewChatThreadPayload: Encodable {
    let requesterUserId: String
    let requesterName: String
    let requesterRole: String
    let adminUserId: String
    let adminName: String
    let adminRole: String
    let title: String
    let lastMessagePreview: String

    enum CodingKeys: String, CodingKey {
        case requesterUserId = "requester_user_id"
        case requesterName = "requester_name"
        case requesterRole = "requester_role"
        case adminUserId = "admin_user_id"
        case adminName = "admin_name"
        case adminRole = "admin_role"
        case title
        case lastMessagePreview = "last_message_preview"
    }
}

private struct ChatThreadUpdatePayload: Encodable {
    let updatedAt: String
    let lastMessagePreview: String

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case lastMessagePreview = "last_message_preview"
    }
}

private struct NewChatMessagePayload: Encodable {
    let threadId: String
    let senderUserId: String
    let senderName: String
    let senderRole: String
    let recipientUserId: String
    let body: String
    let attachmentName: String?
    let attachmentURL: String?
    let attachmentMimeType: String?
    let attachmentStoragePath: String?

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case senderUserId = "sender_user_id"
        case senderName = "sender_name"
        case senderRole = "sender_role"
        case recipientUserId = "recipient_user_id"
        case body
        case attachmentName = "attachment_name"
        case attachmentURL = "attachment_url"
        case attachmentMimeType = "attachment_mime_type"
        case attachmentStoragePath = "attachment_storage_path"
    }
}

private struct SeenMessagePayload: Encodable {
    let seenAt: String

    enum CodingKeys: String, CodingKey {
        case seenAt = "seen_at"
    }
}

private struct DeleteMessagePayload: Encodable {
    let deletedAt: String

    enum CodingKeys: String, CodingKey {
        case deletedAt = "deleted_at"
    }
}

private struct NewNotificationPayload: Encodable {
    let userId: String
    let title: String
    let body: String
    let targetThreadId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case body
        case targetThreadId = "target_thread_id"
    }
}

private struct ReadNotificationPayload: Encodable {
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case isRead = "is_read"
    }
}

private struct RequisitionItemPayload: Encodable {
    let item: String
    let need: Double
    let unit: String
    let ordem: Int
    let stock: Double
    let itemId: String
    let provided: Double
    let subcategoria: String?

    enum CodingKeys: String, CodingKey {
        case item
        case need
        case unit
        case ordem
        case stock
        case itemId = "item_id"
        case provided
        case subcategoria
    }
}

private struct RequisitionItemInsertPayload: Encodable {
    let requisicaoId: String
    let ordem: Int
    let itemId: String
    let nome: String
    let unidade: String
    let subcategoria: String?
    let qtdDisponivel: Double
    let qtdNecessaria: Double
    let qtdFornecida: Double?

    enum CodingKeys: String, CodingKey {
        case requisicaoId = "requisicao_id"
        case ordem
        case itemId = "item_id"
        case nome
        case unidade
        case subcategoria
        case qtdDisponivel = "qtd_disponivel"
        case qtdNecessaria = "qtd_necessaria"
        case qtdFornecida = "qtd_fornecida"
    }
}

private struct RequisitionItemInsertResult: Decodable {
    let id: String
}
