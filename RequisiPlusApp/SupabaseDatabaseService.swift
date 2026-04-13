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
        let path = "/rest/v1/requisicoes?select=id,categoria,setor,solicitante,status,data,created_at,signed_attachment,timestamp&solicitante=eq.\(encodedName)&setor=eq.\(encodedSetor)&order=created_at.desc"
        let records: [RequisicaoRecord] = try await perform(path: path, method: "GET", accessToken: userSession.accessToken)
        return records.enumerated().map { index, record in
            record.toDomain(position: index)
        }
    }

    func createRequisition(
        session userSession: UserSession,
        profile: UserProfile,
        materialType: MaterialType,
        observation: String
    ) async throws -> Requisition {
        let payload = NewRequisitionPayload(
            setor: profile.setor,
            solicitante: profile.name,
            categoria: materialType.title,
            data: DateFormatter.requisitionDate.string(from: Date()),
            items: [],
            status: "pendente",
            solicitanteCpf: profile.cpf,
            solicitanteFuncao: profile.funcao,
            devolucaoMotivo: observation.isEmpty ? nil : observation
        )

        let records: [RequisicaoRecord] = try await perform(
            path: "/rest/v1/requisicoes?select=id,categoria,setor,solicitante,status,data,created_at,signed_attachment,timestamp",
            method: "POST",
            accessToken: userSession.accessToken,
            body: payload,
            preferRepresentation: true
        )

        guard let record = records.first else {
            throw SupabaseDatabaseError.requestFailed("Nao foi possivel confirmar a criacao da requisicao.")
        }

        return record.toDomain(position: 0)
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

private struct RequisicaoRecord: Decodable {
    let id: String
    let categoria: String
    let setor: String
    let solicitante: String
    let status: String
    let data: String
    let createdAt: String?
    let signedAttachment: JSONValue?
    let timestamp: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case categoria
        case setor
        case solicitante
        case status
        case data
        case createdAt = "created_at"
        case signedAttachment = "signed_attachment"
        case timestamp
    }

    func toDomain(position: Int) -> Requisition {
        Requisition(
            id: id,
            code: "REQ-\(String(format: "%04d", (timestamp ?? Int64(position + 1)) % 10000))",
            materialType: categoria,
            sector: setor,
            requestedBy: solicitante,
            status: status,
            date: data,
            requiresDesktopSignature: signedAttachment == nil && status.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains("assin")
        )
    }
}

private struct NewRequisitionPayload: Encodable {
    let setor: String
    let solicitante: String
    let categoria: String
    let data: String
    let items: [String]
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
