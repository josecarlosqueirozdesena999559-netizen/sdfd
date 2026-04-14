import Foundation

enum SupabaseDatabaseError: LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Nao foi possivel montar a URL do banco."
        case .invalidResponse:
            return "Resposta invalida do banco."
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

        throw SupabaseDatabaseError.requestFailed("Usuario autenticado nao encontrado na tabela usuarios.")
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
        return records.map(\.toDomain)
    }

    func createRequisition(
        session userSession: UserSession,
        profile: UserProfile,
        materialType: MaterialType,
        entries: [RequestedItemEntry],
        observation: String
    ) async throws -> Requisition {
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
            throw SupabaseDatabaseError.requestFailed("Nao foi possivel confirmar a criacao da requisicao.")
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
            throw SupabaseDatabaseError.requestFailed("Nao foi possivel interpretar os dados do banco.")
        }
    }
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
