import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("requisi+")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)

                    Text("Entrar")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)

                    Text("Acesso liberado apenas com autenticacao pelo Supabase.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    credentialField(title: "E-mail", text: $email, keyboardType: .emailAddress)
                    secureCredentialField(title: "Senha", text: $password)

                    if let errorMessage = authViewModel.errorMessage, errorMessage.isEmpty == false {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await authViewModel.signIn(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            )
                        }
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(authViewModel.isLoading ? "Entrando..." : "Entrar com Supabase")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.deepBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.7 : 1)
                }

                Text("Use um usuario existente no Supabase Auth para acessar o aplicativo.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 460)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.76), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.deepBlue.opacity(0.12), radius: 24, x: 0, y: 16)
            )
            .padding(20)
        }
    }

    private func credentialField(title: String, text: Binding<String>, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.deepBlue)

            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.cardBlue.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func secureCredentialField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.deepBlue)

            SecureField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.cardBlue.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
