import Foundation

struct UserSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: SupabaseUser

    var bearerToken: String {
        "\(tokenType) \(accessToken)"
    }
}

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let lastSignInAt: String?
    let userMetadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case lastSignInAt = "last_sign_in_at"
        case userMetadata = "user_metadata"
    }

    var displayName: String {
        if let rawName = userMetadata?["name"]?.stringValue, rawName.isEmpty == false {
            return rawName
        }
        if let rawName = userMetadata?["full_name"]?.stringValue, rawName.isEmpty == false {
            return rawName
        }
        if let email {
            return email.components(separatedBy: "@").first?.capitalized ?? email
        }
        return "Usuario"
    }
}

enum AuthDateFormatter {
    static let lastAccessInputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let fallbackInputFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

struct AuthSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case user
    }

    var session: UserSession {
        UserSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: tokenType,
            user: user
        )
    }
}

struct AuthErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
        case message
    }

    var readableMessage: String {
        let rawMessage = errorDescription ?? msg ?? message ?? error ?? "Nao foi possivel concluir a autenticacao."
        let normalized = rawMessage.lowercased()

        if normalized.contains("invalid login credentials") || normalized == "not found" {
            return "E-mail ou senha invalidos."
        }

        if normalized.contains("email not confirmed") {
            return "Confirme seu e-mail antes de entrar."
        }

        return rawMessage
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Valor JSON nao suportado.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
}
