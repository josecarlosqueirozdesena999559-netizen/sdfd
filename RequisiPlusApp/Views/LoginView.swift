import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""
    private let systemName = "RequisiPlus"

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 32, 480)

            ZStack {
                AppTheme.heroGradient
                    .ignoresSafeArea()

                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .offset(x: -geometry.size.width * 0.30, y: -geometry.size.height * 0.20)

                Circle()
                    .fill(AppTheme.skyBlue.opacity(0.16))
                    .frame(width: 360, height: 360)
                    .offset(x: geometry.size.width * 0.28, y: geometry.size.height * 0.32)

                VStack(spacing: 0) {
                    Spacer(minLength: max(24, geometry.safeAreaInsets.top + 8))

                    VStack(spacing: 18) {
                        Text(systemName)
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Sistema de Requisicoes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .multilineTextAlignment(.center)

                        Text("Entre com suas credenciais para acessar a plataforma.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)

                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Entrar")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppTheme.deepBlue)

                            Text("Use seu e-mail institucional e sua senha.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 16) {
                            loginField(
                                icon: "envelope",
                                text: $email,
                                prompt: "E-mail",
                                keyboardType: .emailAddress,
                                field: .email,
                                isSecure: false
                            )

                            loginField(
                                icon: "lock",
                                text: $password,
                                prompt: "Senha",
                                keyboardType: .default,
                                field: .password,
                                isSecure: true
                            )
                        }

                        if let errorMessage = authViewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            submit()
                        } label: {
                            HStack(spacing: 10) {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }

                                Text(authViewModel.isLoading ? "Entrando..." : "Entrar")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppTheme.primaryBlue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: AppTheme.primaryBlue.opacity(0.24), radius: 18, y: 10)
                        }
                        .buttonStyle(.plain)
                        .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                        .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.65 : 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: contentWidth)
                    .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1.2)
                    )
                    .shadow(color: AppTheme.deepBlue.opacity(0.22), radius: 30, y: 16)
                    .padding(.horizontal, 16)

                    Spacer(minLength: max(24, geometry.safeAreaInsets.bottom + 16))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private func loginField(
        icon: String,
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType,
        field: LoginField,
        isSecure: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(focusedField == field ? AppTheme.primaryBlue : AppTheme.textMuted)
                .frame(width: 20)

            Group {
                if isSecure {
                    SecureField(prompt, text: text)
                        .submitLabel(.go)
                        .onSubmit { submit() }
                } else {
                    TextField(prompt, text: text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(keyboardType)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                }
            }
            .autocorrectionDisabled()
            .foregroundStyle(AppTheme.textPrimary)
            .tint(AppTheme.primaryBlue)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.6 : 1)
        )
    }

    private func submit() {
        guard !authViewModel.isLoading, !email.isEmpty, !password.isEmpty else {
            return
        }

        focusedField = nil

        Task {
            await authViewModel.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                password: password
            )
        }
    }
}

private enum LoginField {
    case email
    case password
}
