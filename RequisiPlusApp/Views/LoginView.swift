import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 32, 520)

            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("requisi+")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.deepBlue)

                        Text("Entrar")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Acesse a plataforma com suas credenciais para continuar.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textMuted)
                    }

                    VStack(spacing: 0) {
                        loginField(
                            icon: "envelope",
                            text: $email,
                            prompt: "E-mail",
                            keyboardType: .emailAddress,
                            field: .email,
                            isSecure: false
                        )

                        Divider()
                            .padding(.leading, 44)

                        loginField(
                            icon: "lock",
                            text: $password,
                            prompt: "Senha",
                            keyboardType: .default,
                            field: .password,
                            isSecure: true
                        )
                    }
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.fieldBorder, lineWidth: 1)
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
                        .frame(height: 54)
                        .background(AppTheme.primaryBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                    .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.65 : 1)

                    Spacer()
                }
                .frame(maxWidth: contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.top, max(48, geometry.safeAreaInsets.top + 28))
                .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 16))
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
                .foregroundStyle(focusedField == field ? AppTheme.deepBlue : AppTheme.textMuted)
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
            .tint(AppTheme.deepBlue)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
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
