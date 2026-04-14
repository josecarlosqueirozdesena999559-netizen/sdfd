import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @FocusState private var focusedField: LoginField?

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 32, 620)

            ZStack {
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(showsIndicators: false) {
                        formContent
                            .frame(maxWidth: contentWidth, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 28)
                            .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 16))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
            .onTapGesture {
                focusedField = nil
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("requisi+")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text("Entrar")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            Text("Acesse a plataforma com suas credenciais para fazer login.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.84))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(
            AppTheme.heroGradient
                .ignoresSafeArea(edges: .top)
        )
    }

    private var formContent: some View {
        PrimaryCard(padding: 22) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Seu acesso")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Use seu e-mail e senha para continuar.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                SoftPanel {
                    VStack(spacing: 16) {
                        inputField(
                            title: "E-mail",
                            icon: "envelope.fill",
                            text: $email,
                            prompt: "seu@email.com",
                            keyboardType: .emailAddress,
                            field: .email
                        )

                        secureInputField(
                            title: "Senha",
                            icon: "lock.fill",
                            text: $password,
                            prompt: "Digite sua senha",
                            field: .password
                        )
                    }
                }

                if let errorMessage = authViewModel.errorMessage, !errorMessage.isEmpty {
                    SoftPanel {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    submit()
                } label: {
                    HStack(spacing: 10) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }

                        Text(authViewModel.isLoading ? "Entrando..." : "Entrar")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.deepBlue, AppTheme.primaryBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                .opacity(authViewModel.isLoading || email.isEmpty || password.isEmpty ? 0.65 : 1)
            }
        }
    }

    private func inputField(
        title: String,
        icon: String,
        text: Binding<String>,
        prompt: String,
        keyboardType: UIKeyboardType,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(focusedField == field ? AppTheme.deepBlue : AppTheme.textMuted)
                    .frame(width: 20)

                TextField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.textMuted.opacity(0.65)))
                    .textInputAutocapitalization(.never)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
                    .focused($focusedField, equals: field)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.4 : 1)
            )
        }
    }

    private func secureInputField(
        title: String,
        icon: String,
        text: Binding<String>,
        prompt: String,
        field: LoginField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(focusedField == field ? AppTheme.deepBlue : AppTheme.textMuted)
                    .frame(width: 20)

                SecureField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.textMuted.opacity(0.65)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
                    .tint(AppTheme.deepBlue)
                    .focused($focusedField, equals: field)
                    .submitLabel(.go)
                    .onSubmit {
                        submit()
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(AppTheme.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(focusedField == field ? AppTheme.primaryBlue : AppTheme.fieldBorder, lineWidth: focusedField == field ? 1.4 : 1)
            )
        }
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
