import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published var isLoading = false
    @Published var isRestoringSession = true
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let authService: SupabaseAuthService
    private let sessionStore: SecureSessionStore

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

    func requestPasswordReset(email: String) async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.isEmpty == false else {
            errorMessage = "Informe seu e-mail para recuperar a senha."
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
            try await authService.requestPasswordReset(email: normalizedEmail)
            infoMessage = "Enviamos as instruções de recuperação para o seu e-mail."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        let accessToken = session?.accessToken
        session = nil
        errorMessage = nil
        infoMessage = nil
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
        }
    }

    private func persist(session: UserSession) {
        self.session = session
        errorMessage = nil
        infoMessage = nil
        try? sessionStore.save(session)
    }
}
