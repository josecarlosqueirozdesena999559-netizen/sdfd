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
        let path: String

        if profile.isAdmin {
            path = "/rest/v1/requisicoes?select=*&order=setor.asc,created_at.desc"
        } else {
            let encodedName = profile.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? profile.name
            let encodedSetor = profile.setor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? profile.setor
            path = "/rest/v1/requisicoes?select=*&solicitante=eq.\(encodedName)&setor=eq.\(encodedSetor)&order=created_at.desc"
        }

        let records: [RequisicaoRecord] = try await perform(path: path, method: "GET", accessToken: userSession.accessToken)
        let itemMap = try await fetchRequisitionItems(session: userSession, requisitionIds: records.map(\.id))

        return records.enumerated().map { index, record in
            record.toDomain(
                position: index,
                items: itemMap[record.id] ?? record.legacyItems
            )
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

        async let recordsTask: [ChatThreadRecord] = performOptional(path: path, method: "GET", accessToken: userSession.accessToken)
        async let unreadCountsTask = fetchUnreadMessageCounts(session: userSession, profile: profile)

        let records = try await recordsTask
        let unreadCounts = try await unreadCountsTask

        return records.map {
            $0.toDomain(for: profile, unreadCount: unreadCounts[$0.id] ?? $0.unreadCount ?? 0)
        }
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
            return existing.toDomain(for: profile, unreadCount: existing.unreadCount ?? 0)
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

        return thread.toDomain(for: profile, unreadCount: thread.unreadCount ?? 0)
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

    func markNotificationsAsRead(session userSession: UserSession, notificationIds: [String]) async throws {
        guard notificationIds.isEmpty == false else {
            return
        }

        let encodedIds = notificationIds
            .map { "\"\($0)\"" }
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: ",")

        let payload = ReadNotificationPayload(isRead: true)
        let _: [NotificationRecord] = try await performOptional(
            path: "/rest/v1/user_notifications?id=in.(\(encodedIds))&select=id",
            method: "PATCH",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )
    }

    func registerPushToken(
        session userSession: UserSession,
        profile: UserProfile,
        deviceToken: String,
        bundleIdentifier: String,
        environment: String
    ) async throws {
        let payload = PushTokenPayload(
            userId: profile.id,
            deviceToken: deviceToken,
            platform: "ios",
            apnsEnvironment: environment,
            bundleIdentifier: bundleIdentifier,
            isActive: true,
            lastRegisteredAt: AppDateFormatter.iso8601Basic.string(from: Date())
        )

        guard let url = URL(
            string: "/rest/v1/user_push_tokens?on_conflict=device_token&select=id",
            relativeTo: SupabaseConfig.url
        ) else {
            throw SupabaseDatabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(userSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseDatabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(AuthErrorResponse.self, from: data).readableMessage)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SupabaseDatabaseError.requestFailed(message)
        }
    }

    func createRequisition(
        session userSession: UserSession,
        profile: UserProfile,
        materialType: MaterialType,
        entries: [RequestedItemEntry],
        observation: String
    ) async throws -> Requisition {
        let systemCode = try await getNextSaidaCodigoForRequisition(session: userSession)
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
            saidaCodigo: systemCode,
            numeroRequisicao: systemCode,
            numeroSolicitacao: systemCode,
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

        return record.toDomain(
            position: 0,
            items: itemRows.enumerated().map { index, row in
                RequisitionItem(
                    id: row.itemId,
                    name: row.nome,
                    unit: row.unidade,
                    currentBalance: row.qtdDisponivel,
                    requestedQuantity: row.qtdNecessaria,
                    providedQuantity: row.qtdFornecida,
                    sortOrder: index
                )
            }
        )
    }

    private static func encodeJSONString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func getNextSaidaCodigoForRequisition(session userSession: UserSession) async throws -> String {
        let prefix = DateFormatter.requisitionCodePrefix.string(from: Date())
        let encodedPrefix = "\(prefix)*".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(prefix)*"
        let path = "/rest/v1/requisicoes?select=saida_codigo&saida_codigo=like.\(encodedPrefix)&order=saida_codigo.desc&limit=1"
        let records: [RequisicaoCodigoRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)

        guard let latestCode = records.compactMap(\.saidaCodigo).first else {
            return "\(prefix)001"
        }

        let sequenceText = String(latestCode.dropFirst(prefix.count))
        let nextSequence = (Int(sequenceText) ?? 0) + 1
        return "\(prefix)\(String(format: "%03d", nextSequence))"
    }

    private func fetchRequisitionItems(
        session userSession: UserSession,
        requisitionIds: [String]
    ) async throws -> [String: [RequisitionItem]] {
        guard requisitionIds.isEmpty == false else {
            return [:]
        }

        let encodedIds = requisitionIds
            .map { "\"\($0)\"" }
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
            .joined(separator: ",")

        let path = "/rest/v1/requisicao_itens?select=id,requisicao_id,ordem,nome,unidade,qtd_disponivel,qtd_necessaria,qtd_fornecida&requisicao_id=in.(\(encodedIds))&order=ordem.asc"
        let records: [RequisitionItemRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)

        return records.reduce(into: [:]) { partialResult, record in
            partialResult[record.requisicaoId, default: []].append(record.toDomain())
        }
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
            if case .requestFailed(let message) = error, isRecoverableSchemaMessage(message), let empty = emptyValue(for: Response.self) {
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
            if case .requestFailed(let message) = error, isRecoverableSchemaMessage(message), let empty = emptyValue(for: Response.self) {
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

    private func fetchUnreadMessageCounts(
        session userSession: UserSession,
        profile: UserProfile
    ) async throws -> [String: Int] {
        let path = "/rest/v1/chat_messages?select=thread_id&recipient_user_id=eq.\(profile.id)&seen_at=is.null&deleted_at=is.null"
        let rows: [UnreadThreadMessageRecord] = try await performOptional(path: path, method: "GET", accessToken: userSession.accessToken)

        return rows.reduce(into: [:]) { partialResult, row in
            partialResult[row.threadId, default: 0] += 1
        }
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
        if Response.self == [PushTokenRecord].self {
            return [] as? Response
        }
        if Response.self == [RequisitionItemRecord].self {
            return [] as? Response
        }
        return nil
    }

    private func isRecoverableSchemaMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("relation")
            || normalized.contains("does not exist")
            || normalized.contains("could not find")
            || normalized.contains("column")
            || normalized.contains("schema cache")
            || normalized.contains("no rows found")
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
            targetThreadId: targetThreadId,
            targetSection: targetThreadId == nil ? AppSection.verRequisicoes.rawValue : AppSection.chat.rawValue,
            isSystemNotification: false
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

    func toDomain(for profile: UserProfile, unreadCount: Int) -> ChatThread {
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
            unreadCount: unreadCount
        )
    }
}

private struct UnreadThreadMessageRecord: Decodable {
    let threadId: String

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
    }
}

private struct PushTokenRecord: Decodable {
    let id: String
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
    let items: JSONValue?

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
        case items
    }

    func toDomain(position: Int, items: [RequisitionItem]) -> Requisition {
        let realCode = systemCode

        return Requisition(
            id: id,
            code: realCode ?? resolvedCode(fallbackPosition: position),
            hasRealCode: realCode != nil,
            materialType: categoria,
            sector: setor,
            requestedBy: solicitante,
            status: status,
            date: data,
            requiresDesktopSignature: signedAttachment == nil && status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains("assin"),
            items: items.sorted { $0.sortOrder < $1.sortOrder }
        )
    }

    var legacyItems: [RequisitionItem] {
        items?.legacyRequisitionItems ?? []
    }

    private func resolvedCode(fallbackPosition _: Int) -> String {
        let realCode = systemCode

        if let realCode {
            return realCode
        }

        return "Aguardando código do sistema"
    }

    var systemCode: String? {
        [
            saidaCodigo,
            numeroRequisicao?.displayText,
            numeroSolicitacao?.displayText,
            codigo?.displayText,
            numero?.displayText
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { $0.isEmpty == false && $0.isUUIDLike == false }
    }
}

private struct RequisicaoCodigoRecord: Decodable {
    let saidaCodigo: String?

    enum CodingKeys: String, CodingKey {
        case saidaCodigo = "saida_codigo"
    }
}

private struct NewRequisitionPayload: Encodable {
    let setor: String
    let solicitante: String
    let categoria: String
    let data: String
    let items: String
    let status: String
    let saidaCodigo: String?
    let numeroRequisicao: String?
    let numeroSolicitacao: String?
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
        case saidaCodigo = "saida_codigo"
        case numeroRequisicao = "numero_requisicao"
        case numeroSolicitacao = "numero_solicitacao"
        case solicitanteCpf = "solicitante_cpf"
        case solicitanteFuncao = "solicitante_funcao"
        case devolucaoMotivo = "devolucao_motivo"
    }
}

private extension String {
    var isUUIDLike: Bool {
        UUID(uuidString: trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }
}

private extension DateFormatter {
    static let requisitionDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    static let requisitionCodePrefix: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "ddMMyy"
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

private struct PushTokenPayload: Encodable {
    let userId: String
    let deviceToken: String
    let platform: String
    let apnsEnvironment: String
    let bundleIdentifier: String
    let isActive: Bool
    let lastRegisteredAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceToken = "device_token"
        case platform
        case apnsEnvironment = "apns_environment"
        case bundleIdentifier = "bundle_identifier"
        case isActive = "is_active"
        case lastRegisteredAt = "last_registered_at"
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

private struct RequisitionItemRecord: Decodable {
    let id: String
    let requisicaoId: String
    let ordem: JSONValue?
    let nome: String?
    let unidade: String?
    let qtdDisponivel: JSONValue?
    let qtdNecessaria: JSONValue?
    let qtdFornecida: JSONValue?

    enum CodingKeys: String, CodingKey {
        case id
        case requisicaoId = "requisicao_id"
        case ordem
        case nome
        case unidade
        case qtdDisponivel = "qtd_disponivel"
        case qtdNecessaria = "qtd_necessaria"
        case qtdFornecida = "qtd_fornecida"
    }

    func toDomain() -> RequisitionItem {
        RequisitionItem(
            id: id,
            name: nome?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Item sem descrição",
            unit: unidade?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "-",
            currentBalance: qtdDisponivel?.doubleValue,
            requestedQuantity: qtdNecessaria?.doubleValue,
            providedQuantity: qtdFornecida?.doubleValue,
            sortOrder: ordem?.intValue ?? 0
        )
    }
}

private struct LegacyRequisitionItemRecord: Decodable {
    let item: String?
    let unit: String?
    let stock: Double?
    let need: Double?
    let provided: Double?

    func toDomain(index: Int) -> RequisitionItem {
        RequisitionItem(
            id: "legacy-item-\(index)",
            name: item?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Item sem descrição",
            unit: unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "-",
            currentBalance: stock,
            requestedQuantity: need,
            providedQuantity: provided,
            sortOrder: index
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension JSONValue {
    var intValue: Int? {
        switch self {
        case .number(let value):
            return Int(value)
        case .string(let value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            let normalized = value
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(normalized)
        default:
            return nil
        }
    }

    var legacyRequisitionItems: [RequisitionItem] {
        switch self {
        case .array(let values):
            return values.enumerated().compactMap { index, value in
                value.legacyRequisitionItem(index: index)
            }
        case .string(let rawValue):
            guard let data = rawValue.data(using: .utf8) else {
                return []
            }

            let decoder = JSONDecoder()
            let records = (try? decoder.decode([LegacyRequisitionItemRecord].self, from: data)) ?? []
            return records.enumerated().map { index, record in
                record.toDomain(index: index)
            }
        default:
            return []
        }
    }

    private func legacyRequisitionItem(index: Int) -> RequisitionItem? {
        guard case .object(let fields) = self else {
            return nil
        }

        return RequisitionItem(
            id: fields["item_id"]?.stringValue ?? "legacy-item-\(index)",
            name: fields["item"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Item sem descrição",
            unit: fields["unit"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "-",
            currentBalance: fields["stock"]?.doubleValue,
            requestedQuantity: fields["need"]?.doubleValue,
            providedQuantity: fields["provided"]?.doubleValue,
            sortOrder: fields["ordem"]?.intValue ?? index
        )
    }
}
