import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordResetFlow = false
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    private let systemName = "Requisi+"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeroHeader(
                        title: "Acessar conta",
                        brandText: systemName.lowercased(),
                        unreadNotificationCount: 0,
                        onNotificationsTap: {},
                        showsNotificationButton: false
                    )
                    .frame(minHeight: 244, alignment: .bottom)

                    Spacer(minLength: 28)
                    formSection
                    Spacer(minLength: max(48, geometry.safeAreaInsets.bottom + 20))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private var formSection: some View {
        PrimaryCard {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(isPasswordResetFlow ? "Atualizar senha" : "Entrar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)

                    Text(subtitleText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }

                if isPasswordResetFlow {
                    passwordResetStageBadge
                }

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
                    prompt: isPasswordResetFlow ? "Senha atual" : "Senha",
                    keyboardType: .default,
                    field: .password,
                    isSecure: true
                )

                if isPasswordResetFlow, authViewModel.isPasswordResetReady {
                    loginField(
                        icon: "key",
                        text: $newPassword,
                        prompt: "Nova senha",
                        keyboardType: .default,
                        field: .newPassword,
                        isSecure: true
                    )

                    loginField(
                        icon: "checkmark.shield",
                        text: $confirmNewPassword,
                        prompt: "Confirmar nova senha",
                        keyboardType: .default,
                        field: .confirmNewPassword,
                        isSecure: true
                    )
                }

                helperActions

                if let errorMessage = authViewModel.errorMessage, !errorMessage.isEmpty {
                    feedbackMessage(errorMessage, color: Color.red.opacity(0.9))
                }

                if let infoMessage = authViewModel.infoMessage, !infoMessage.isEmpty {
                    feedbackMessage(infoMessage, color: AppTheme.success)
                }

                Button {
                    if isPasswordResetFlow {
                        submitPasswordResetFlow()
                    } else {
                        submit()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(primaryButtonTitle)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primaryBlue, AppTheme.midBlue.opacity(0.88)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
                    .shadow(color: AppTheme.primaryBlue.opacity(0.22), radius: 14, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isPrimaryButtonDisabled)
                .opacity(isPrimaryButtonDisabled ? 0.7 : 1)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 520)
        .padding(.top, 10)
    }

    private var passwordResetStageBadge: some View {
        Text(authViewModel.isPasswordResetReady ? "Etapa 2 de 2: crie sua nova senha" : "Etapa 1 de 2: valide seu acesso")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(AppTheme.primaryBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.skyBlue.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var helperActions: some View {
        HStack {
            if isPasswordResetFlow {
                Button("Cancelar") {
                    cancelPasswordResetFlow()
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)
            } else {
                Spacer()

                Button("Esqueci minha senha") {
                    focusedField = .email
                    isPasswordResetFlow = true
                    authViewModel.cancelPasswordResetFlow()
                    newPassword = ""
                    confirmNewPassword = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryBlue)
                .disabled(authViewModel.isLoading)
                .opacity(authViewModel.isLoading ? 0.7 : 1)
            }

            Spacer()
        }
    }

    private func feedbackMessage(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleText: String {
        if isPasswordResetFlow {
            if authViewModel.isPasswordResetReady {
                return "Defina sua nova senha e volte a acessar o app com segurança."
            }
            return "Informe seu e-mail e sua senha atual para confirmar sua identidade."
        }

        return "Use seu e-mail e sua senha para continuar."
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
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(focusedField == field ? AppTheme.primaryBlue : AppTheme.primaryBlue.opacity(0.78))
                .frame(width: 22)

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: text,
                        prompt: Text(prompt)
                            .foregroundStyle(AppTheme.textMuted)
                    )
                    .submitLabel(field == .confirmNewPassword ? .go : .next)
                    .onSubmit {
                        switch field {
                        case .email:
                            focusedField = .password
                        case .password:
                            if isPasswordResetFlow {
                                if authViewModel.isPasswordResetReady {
                                    focusedField = .newPassword
                                } else {
                                    submitPasswordResetFlow()
                                }
                            } else {
                                submit()
                            }
                        case .newPassword:
                            focusedField = .confirmNewPassword
                        case .confirmNewPassword:
                            submitPasswordResetFlow()
                        }
                    }
                } else {
                    TextField(
                        "",
                        text: text,
                        prompt: Text(prompt)
                            .foregroundStyle(AppTheme.textMuted)
                    )
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
        .frame(height: 54)
        .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(focusedField == field ? AppTheme.primaryBlue.opacity(0.9) : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.4 : 1)
        )
        .shadow(color: AppTheme.deepBlue.opacity(0.04), radius: 8, y: 4)
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

    private func submitPasswordResetFlow() {
        guard authViewModel.isLoading == false else {
            return
        }

        focusedField = nil

        if authViewModel.isPasswordResetReady {
            Task {
                await authViewModel.completePasswordReset(
                    newPassword: newPassword,
                    confirmPassword: confirmNewPassword
                )
            }
        } else {
            Task {
                await authViewModel.beginPasswordReset(email: email, currentPassword: password)
            }
        }
    }

    private func cancelPasswordResetFlow() {
        focusedField = nil
        isPasswordResetFlow = false
        newPassword = ""
        confirmNewPassword = ""
        authViewModel.cancelPasswordResetFlow()
    }

    private var primaryButtonTitle: String {
        if authViewModel.isLoading {
            if isPasswordResetFlow {
                return authViewModel.isPasswordResetReady ? "Salvando nova senha..." : "Validando acesso..."
            }
            return "Entrando..."
        }

        if isPasswordResetFlow {
            return authViewModel.isPasswordResetReady ? "Criar nova senha" : "Continuar"
        }

        return "Entrar"
    }

    private var isPrimaryButtonDisabled: Bool {
        if authViewModel.isLoading {
            return true
        }

        if isPasswordResetFlow {
            if authViewModel.isPasswordResetReady {
                return newPassword.isEmpty || confirmNewPassword.isEmpty
            }

            return email.isEmpty || password.isEmpty
        }

        return email.isEmpty || password.isEmpty
    }
}

private enum LoginField {
    case email
    case password
    case newPassword
    case confirmNewPassword
}
