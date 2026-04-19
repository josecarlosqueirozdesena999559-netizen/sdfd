import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published var isLoading = false
    @Published var isRestoringSession = true
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var isPasswordResetReady = false

    private let authService: SupabaseAuthService
    private let sessionStore: SecureSessionStore
    private var pendingPasswordResetSession: UserSession?

    init(
        authService: SupabaseAuthService = SupabaseAuthService(),
        sessionStore: SecureSessionStore = SecureSessionStore()
    ) {
        self.authService = authService
        self.sessionStore = sessionStore

        Task {
            await restoreSession()
        }
    }

    var isAuthenticated: Bool {
        session != nil
    }

    var displayName: String {
        session?.user.displayName ?? "Usuário"
    }

    var email: String {
        session?.user.email ?? "Sem e-mail"
    }

    var lastAccessDescription: String {
        guard let rawValue = session?.user.lastSignInAt,
              let date = AuthDateFormatter.lastAccessInputFormatter.date(from: rawValue)
                ?? AuthDateFormatter.fallbackInputFormatter.date(from: rawValue) else {
            return "Acesso validado pelo Supabase"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM/yyyy 'as' HH:mm"
        return formatter.string(from: date)
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        isPasswordResetReady = false
        pendingPasswordResetSession = nil

        defer {
            isLoading = false
        }

        do {
            let freshSession = try await authService.signIn(email: email, password: password)
            persist(session: freshSession)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginPasswordReset(email: String, currentPassword: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCurrentPassword = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false else {
            errorMessage = "Informe seu e-mail para continuar."
            infoMessage = nil
            return
        }

        guard normalizedCurrentPassword.isEmpty == false else {
            errorMessage = "Informe sua senha atual para continuar."
            infoMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil
        isPasswordResetReady = false
        pendingPasswordResetSession = nil

        defer {
            isLoading = false
        }

        do {
            let freshSession = try await authService.signIn(email: normalizedEmail, password: normalizedCurrentPassword)
            pendingPasswordResetSession = freshSession
            isPasswordResetReady = true
            infoMessage = "Crie sua nova senha para concluir o acesso."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completePasswordReset(newPassword: String, confirmPassword: String) async {
        let normalizedPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let pendingPasswordResetSession else {
            errorMessage = "Confirme seu e-mail e sua senha atual antes de criar a nova senha."
            infoMessage = nil
            isPasswordResetReady = false
            return
        }

        guard normalizedPassword.isEmpty == false else {
            errorMessage = "Informe a nova senha."
            infoMessage = nil
            return
        }

        guard normalizedPassword.count >= 6 else {
            errorMessage = "A nova senha deve ter pelo menos 6 caracteres."
            infoMessage = nil
            return
        }

        guard normalizedPassword == normalizedConfirmPassword else {
            errorMessage = "A confirmação da senha não confere."
            infoMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            try await authService.updatePassword(
                accessToken: pendingPasswordResetSession.accessToken,
                newPassword: normalizedPassword
            )
            persist(session: pendingPasswordResetSession)
            infoMessage = "Senha atualizada com sucesso."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelPasswordResetFlow() {
        pendingPasswordResetSession = nil
        isPasswordResetReady = false
        errorMessage = nil
        infoMessage = nil
    }

    func signOut() {
        let accessToken = session?.accessToken
        session = nil
        errorMessage = nil
        infoMessage = nil
        isPasswordResetReady = false
        pendingPasswordResetSession = nil
        sessionStore.clear()

        if let accessToken {
            Task {
                await authService.signOut(accessToken: accessToken)
            }
        }
    }

    private func restoreSession() async {
        defer {
            isRestoringSession = false
        }

        guard let cachedSession = try? sessionStore.load() else {
            return
        }

        do {
            if let updatedUser = try? await authService.fetchUser(accessToken: cachedSession.accessToken) {
                persist(
                    session: UserSession(
                        accessToken: cachedSession.accessToken,
                        refreshToken: cachedSession.refreshToken,
                        expiresIn: cachedSession.expiresIn,
                        tokenType: cachedSession.tokenType,
                        user: updatedUser
                    )
                )
                return
            }

            let refreshedSession = try await authService.refreshSession(refreshToken: cachedSession.refreshToken)
            persist(session: refreshedSession)
        } catch {
            sessionStore.clear()
            session = nil
            pendingPasswordResetSession = nil
            isPasswordResetReady = false
        }
    }

    private func persist(session: UserSession) {
        self.session = session
        errorMessage = nil
        infoMessage = nil
        pendingPasswordResetSession = nil
        isPasswordResetReady = false
        try? sessionStore.save(session)
    }
}
