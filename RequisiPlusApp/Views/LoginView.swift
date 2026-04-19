import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""
    private let systemName = "Requisi+"

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    AppHeroHeader(
                        title: "Acessar conta",
                        brandText: systemName.lowercased(),
                        unreadNotificationCount: 0,
                        onNotificationsTap: {}
                    )

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
                    Text("Entrar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.deepBlue)

                    Text("Use seu e-mail e sua senha para continuar.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
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
                    prompt: "Senha",
                    keyboardType: .default,
                    field: .password,
                    isSecure: true
                )

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
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.7 : 1)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: 520)
        .padding(.top, 10)
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
        .frame(height: 54)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
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
}

private enum LoginField {
    case email
    case password
}
