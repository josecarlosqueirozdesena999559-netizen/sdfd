import Foundation

enum SupabaseAuthError: LocalizedError {
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Resposta invalida do Supabase."
        case .requestFailed(let message):
            return message
        }
    }
}

struct SupabaseAuthService {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func signIn(email: String, password: String) async throws -> UserSession {
        let request = try makeRequest(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            accessToken: nil,
            body: ["email": email, "password": password]
        )

        let response: AuthSessionResponse = try await perform(request)
        return response.session
    }

    func refreshSession(refreshToken: String) async throws -> UserSession {
        let request = try makeRequest(
            path: "/auth/v1/token?grant_type=refresh_token",
            method: "POST",
            accessToken: nil,
            body: ["refresh_token": refreshToken]
        )

        let response: AuthSessionResponse = try await perform(request)
        return response.session
    }

    func fetchUser(accessToken: String) async throws -> SupabaseUser {
        let request = try makeRequest(
            path: "/auth/v1/user",
            method: "GET",
            accessToken: accessToken
        )

        return try await perform(request)
    }

    func signOut(accessToken: String) async {
        guard let request = try? makeRequest(path: "/auth/v1/logout", method: "POST", accessToken: accessToken) else {
            return
        }

        _ = try? await session.data(for: request)
    }

    private func makeRequest(path: String, method: String, accessToken: String?, body: [String: String]? = nil) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: SupabaseConfig.url) else {
            throw SupabaseAuthError.requestFailed("Falha ao montar a URL de autenticacao do Supabase.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw SupabaseAuthError.requestFailed("Endpoint de autenticação não encontrado. Revise a URL do projeto Supabase e se o Auth está habilitado.")
            }

            let message = (try? decoder.decode(AuthErrorResponse.self, from: data).readableMessage)
                ?? String(data: data, encoding: .utf8)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw SupabaseAuthError.requestFailed(message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw SupabaseAuthError.requestFailed("Não foi possível interpretar a resposta do Supabase.")
        }
    }
}
